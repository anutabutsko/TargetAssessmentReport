# Check to improve: [Update]

#===============================================================================
# PACKAGES 
#===============================================================================
pacman::p_load(tidyverse, knitr, stringr, readr, 
               openxlsx, writexl, readxl, magrittr, countries)


#===============================================================================
# DATA IMPORT 
#===============================================================================
# Setup ------------------------------------------------------------------------
cty <- readline(prompt = "Country name: ")

date <- format(Sys.Date(), "%d%b%y")
date <- ifelse(substr(date, 1, 1) == "0", 
               substr(date, 2, nchar(date)), 
               date)

mrgd <- menu(c("Yes", "No"), 
             title = "Does the country data contain any merged cells?") # make this into an automation with fill()? [Update]

languages <- c("English", "Spanish", "French") # add more languages if/when necessary
lang <- menu(languages, title = "Select the country data language:")
lang <- languages[lang]

`%not_in%` <- negate(`%in%`)


# Path and file ----------------------------------------------------------------
#setwd("../../../../")
setwd(paste0("data/countries/", str_replace(tolower(cty), "\\s", "_"), "/original"))

data <- list.files(pattern = "\\.(csv|xlsx)$", full.names = TRUE)
data <- substr(data, 2, nchar(data))


# Encoding ---------------------------------------------------------------------
encod <- if (lang == languages[1]) {
  "UTF-8" # most widely used, more modern, perfect for English (ASCII is a subset of UTF-8)
} else if (lang == languages[2] | lang == languages[3]) {
  "latin1" # "UTF-8" + (á, à, é, ê, ó, ô, ú, ...), perfect for Latin languages (“ISO-8859-1”, “ISO-8859-15”, “ISO-8859-2”)
} else if (lang == "German" | lang == "E. European") {
  "windows-1252" # "latin1" + (ß, ü, ö, ä, …), perfect for German & E. Europe
} else if (lang == "C. European") {
  "windows-1250"
} else if (lang == "Russian") {
  "windows-1251" # Cyrilic, Slavic languages
} else if (lang == "Arabic") {
  "windows-1256" # (“ISO-8859-6”)
} 
# If the language is not clear (or if you want to be safe), use:
#guess_encoding(substr(data, 2, nchar(data)))[1]

if (substr(data, str_locate(data, "\\.[a-z]{3,4}"), nchar(data)) == ".csv") {
  df <- read_csv(data, locale = locale(encoding = encod)) # read_csv() is better than read.csv()
} else if (substr(data, str_locate(data, "\\.[a-z]{3,4}"), nchar(data)) == ".xlsx") {
  sheets <- excel_sheets(paste0(getwd(), data))
  # select sheet/tab name
  sheet_ref <- menu(sheets, title = "Select the country data sheet/tab:")
  sheet <- sheets[sheet_ref]
  df <- read_excel(paste0(getwd(), data), sheet = sheet) # read_excel() is better than read.xlsx()/read_xlsx() and understands encoding automatically (!)
} else {
  stop("The file's format is neither .xlsx nor .csv")
}


#===============================================================================
# DATA TWEAKS
#===============================================================================

# Columns ----------------------------------------------------------------------
colnames(df)
menu(c("Yes", "No"), title = ">>> ATTENTION <<<\nHave you had a proper look at the column names (right above)?")
########################### Country changes (start) ############################
if (cty == "Tanzania") {
  # Properly names the columns
  cnames <- df[2, ]
  cnames[1] <- "Country"
  colnames(df) <- cnames
  # Removes duplicated column names IN ROWS
  df <- df %>% 
    filter(!grepl("Target Text", .[[2]]), !grepl("Target Name", .[[3]]), 
           !grepl("Source or Document", .[[4]]), !grepl("TargetSource URL", .[[5]]), 
           !grepl("Theme", .[[6]]))
} else if (cty == "Uzbekistan") {
  df <- df %>% 
    mutate(`Source or Document...4` = ifelse(`Source or Document...5` == "NDC2.0", 
                                             `Source or Document...5`, 
                                             `Source or Document...4`))
  df <- df[, -c(5, 7)]
}
############################ Country changes (end) #############################

# Removes
df <- df %>% 
  # ...unnecessary extra columns (keep adding)
  select(-any_of(c("X", "index"))) %>% 
  # ...empty columns
  select(where(~ !all(is.na(.) | . == "")))

# Renames the columns to their proper names
rename_cols <- function(name) {
  case_when(
    str_detect(name, "\\b[Cc]ountry|[Pp]a[ií]s\\b") ~ "Country", # detects "Country" and variations (keep adding)
    str_detect(name, "\\b[Tt]argets?|[Mn]etas?\\b") & # detects "Target" and variations (keep adding)
      str_detect(name, "\\b[Nn]ame|[Nn]ombre\\b") ~ "Target Name", # detects "Name" and variations (keep adding)
    str_detect(name, "\\b[Tt]argets?|[Mm]etas?\\b") & # detects "Target" and variations (keep adding)
      str_detect(name, "\\b[Tt]exto?\\b") ~ "Target Text", # detects "Text" and variations (keep adding)
    str_detect(name, "\\b[Tt]hemes?|[Tt]emas?\\b") | # detects "Theme" and variations (keep adding)
      str_detect(name, "\\b[Cc]onventions?|[Cc]onvenci[oó]n(es)?\\b") ~ "Convention", # detects "Convention" and variations (keep adding)
    str_detect(name, "(?i)URL") ~ "Source", # detects "URL" and variations (keep adding)
    str_detect(name, "\\b[Ss]ources?|[Ff]uentes?\\b|[Dd]ocuments?|[Dd]ocumentos?") ~ "Document", # detects "Source(s)" and variations (keep adding)
    TRUE ~ name
  )
}
df <- df %>% 
  rename_with(rename_cols, .cols = everything())

# Rows -------------------------------------------------------------------------
# Removes empty rows
df <- df %>% 
  filter(!if_all(everything(), ~ is.na(.) | . == ""))
########################### Country changes (start) ############################
if (cty == "Tanzania") {
  df <- df[-c(22, 23, 60, 75, 86, 87, 93, 99, 105, 111, 117, 123, 129, 135, 147), ]
}
############################ Country changes (end) #############################

# Check #1 (country name) ------------------------------------------------------
if (length(unique(df$Country)) != 1) {
  View(df)
  message(paste(unique(df$Country), collapse = ", ")) # Maybe automate this so that if it's either county name of NA, just do fill()? [Update]
  menu(c("Yes", "No"), title = ">> WARNING <<\nThe country name is not unique!\nLook at the View() pane opened above.\n\nWere you able to identify why?")
} else {
  message("[√] Only one country name appears.")
}
########################### Country changes (start) ############################
if (cty == "Tanzania") {
  # properly add the country name
  df <- df %>% mutate(Country = cty)
} else if (cty == "Uzbekistan") {
  df <- df %>% fill(1, .direction = "down")
}
############################ Country changes (end) #############################

# Check #2 (country name language) ---------------------------------------------
df <- df %>% 
  mutate(Country = country_name(cty, to = "name_en"))
if (cty == unique(df$Country)) {
  message("[√] All good!")
} else {
  message(paste0("Seems like '", cty, "' is not the same as '", unique(df$Country), "'"))
}
########################### Country changes (start) ############################
if (cty == "Tanzania") {
  # Keeps name simple
  df <- df %>% mutate(Country = substr(Country, 1, str_locate(Country, ",")-1))
}
############################ Country changes (end) #############################

# Check #3 (NAs) ---------------------------------------------------------------
df <- df %>%
  mutate(across(everything(), ~ ifelse(. %in% c("N/A", "NA"), NA, .)))
if (length(colnames(df)[colSums(is.na(df)) > 0]) != 0) {
  View(df)
  message(paste(colnames(df)[colSums(is.na(df)) > 0], collapse = "\n"))
  menu(c("Yes", "No"), title = ">> WARNING <<\nThe columns above contain NAs!\nLook at the View() pane opened above.\n\nWere you able to identify why?")
} else {
  message("[√] No NAs detected.")
}
########################### Country changes (start) ############################
if (cty == "Tanzania") {
  df <- df %>% 
    mutate(Source = ifelse(Document == "National Energy Compact for Tanzania" | Document == "Draft Green Legacy Document for Zanzibar 2023", 
                           "", 
                           Source)) # (ø)
  # corrects NA cells that were part of a merged cell
  df <- df %>% fill(c(2, 4:6), .direction = "down") # all related to un-merged cells [Update]
}
############################ Country changes (end) #############################

# Check #4 (swapped target name and text) --------------------------------------
if (all(nchar(df$`Target Name`) < nchar(df$`Target Text`)) == "FALSE") {
  View(df %>% 
         filter(nchar(df$`Target Name`) > nchar(df$`Target Text`)))
  menu(c("Yes", "No"), title = ">> WARNING <<\nLooks like some Target Names and Target Texts are swapped!\nLook at the View() pane opened above.\n\nWere you able to identify why?")
} else {
  message("[√] Target Name and Target Text seem to be in the right place.")
}
########################### Country changes (start) ############################
if (cty == "Tanzania") {
  df_aux <- df %>% 
    filter(Document == "Tanzania’s NDC (2021)") %>% 
    mutate(tmp = `Target Name`, 
           `Target Name` = `Target Text`) %>% 
    mutate(`Target Text` = tmp) %>% 
    select(-tmp) %>% 
    ungroup()
  df <- df %>% 
    filter(Document != "Tanzania’s NDC (2021)")
  df <- rbind(df, df_aux) # there are 3 cases where the target name is longer than the target text - just because it is!
} else if (cty == "Dominican Republic") {
  NULL # Gobernanza Climática 6.1 is just a non-target
}
############################ Country changes (end) #############################

# Check #5 (empty cells) -------------------------------------------------------
if (length(colnames(df)[colSums(df == '') > 0]) != 0) {
  View(filter(df, !!sym(colnames(df)[colSums(df == '') > 0]) == ''))
  message(paste(colnames(df)[colSums(df == '') > 0], collapse = "\n"))
  menu(c("Yes", "No"), title = ">> WARNING <<\nThe columns indicated above contain empty spaces.\n\nWere you able to identify why?")
} else {
    message("[√] No empty cells detected.")
}
########################### Country changes (start) ############################
if (cty == "Tanzania") {
  filter(df, !!sym(paste(colnames(df)[colSums(df == '') > 0], collapse = "\n")) == "")$Document %>% 
    unique() # same as the docs specified in ø (Check #3), so this '' are normal
}
############################ Country changes (end) #############################

# Check #6 (unique target names)
if (nrow(df) == length(unique(df$`Target Name`))) {
  message('[√] All target names are uniquely defined (like an identifier)')
} else {
  View(df %>% 
         filter(`Target Name` %in% names(table(df$`Target Name`))[table(df$`Target Name`) > 1]))
  message(paste(shQuote(unique((df %>% filter(`Target Name` %in% names(table(df$`Target Name`))[table(df$`Target Name`) > 1]))$Document)), collapse = ", "))
  menu(c("Yes", "No"), title = ">> WARNING <<\nTarget names are NOT uniquely defined - like an identifier!\nCheck each of the documents above, one at a time.\n\nHave you had a proper look?")
}
########################### Country changes (start) ############################
if (cty == "Tanzania") {
  #View(filter(df, Document == "Tanzania’s NDC (2021)")) # NDC: un-merged cells
  df_aux <- df %>% 
    filter(Document == "Tanzania’s NDC (2021)") %>% 
    group_by(`Target Name`) %>% 
    mutate(`Target Name` = paste0(`Target Name`, " ", row_number())) %>% 
    ungroup()
  df <- df %>% 
    filter(Document != "Tanzania’s NDC (2021)")
  df <- rbind(df, df_aux)
  #View(filter(df, Document == "NCCRS (2021–2026)")) # repeated names with ZCCRS
  #View(filter(df, Document == "Zanzibar Climate Change Strategy (2014–2030)")) # repeated names with NCCRS
  df <- df %>% 
    mutate(`Target Name` = ifelse(Document == "Zanzibar Climate Change Strategy (2014–2030)", 
                                  paste(`Target Name`, "Z", sep = " "), 
                                  `Target Name`))
}
############################ Country changes (end) #############################

# Check #7 (URLs) --------------------------------------------------------------
urls <- df %>% 
  select(Document, Source) %>% unique()

if (length(unique(urls$Document)) != nrow(urls)) {
  View(filter(urls, Document %in% names(table(Document))[table(Document) >= 2]))
  message(">> WARNING <<\nSome documents seem to have multiple URLs. \nCheck what's going on in column 'Source' in the View() pane opened above.")
  menu(c("Yes", "No"), title = "Have you taken note of this?")
} else {
  message("[√] Seems like each document has a single URL reference")
}
########################### Country changes (start) ############################
if (cty == "Tanzania") {
  df <- df %>% 
    mutate(Source = ifelse(Document == "National Biodiversity Target via Online Reporting Tool", 
                           filter(df, Document %in% names(table(Document))[table(Document) >= 2])$Source[3], 
                           Source)) # other documents share a same link, so it's still normal that Check #7 would not clear
} else if (cty == "Uzbekistan") {
  df <- df %>% 
    mutate(Source = ifelse(Document == "BTR1 of Uzbekistan", urls$Source[32], Source), 
           Source = ifelse(Document == "CBD Online Reporting Tool", urls$Source[1], Source))
}
############################ Country changes (end) #############################

# General cleaning -------------------------------------------------------------
df <- df %>%  
  # eliminates empty rows
  filter(!if_all(everything(), ~ is.na(.) | . == "")) %>% 
  # removes leading and lagging white spaces
  mutate(`Target Text` = str_trim(`Target Text`), 
         `Target Name` = str_trim(`Target Name`), 
         Document = str_trim(Document)) %>% 
  # removes double or triple consecutive white spaces
  mutate(`Target Text` = str_squish(`Target Text`)) %>% # better than str_replace_all(`Target Text`, "\\s+", " ")
  # removes "non-breaking", "thin", "zero-width", "narrow no-break", "medium mathematical" and "ideographical" spaces
  mutate(`Target Text` = str_replace_all(`Target Text`, "[\u00A0\u2000-\u200D\u202F\u205F\u3000]", " "))

#df <- df %>% 
  # removes country names from the Document
  #mutate(Document = gsub(cty, "", Document)) %>% # should we remove country names from the documents? [Update]
  #mutate(Document = gsub("('s|’s)", "", Document))

df <- df %>% 
  # creates a simple acronym for the name of the document (Doc)
  mutate(Doc = str_replace_all(Document, "[^A-Z]", "")) %>% 
  # creates the "target types" (NDC Targets, National Biodiversity Targets (NBTs) and Other targets)
  mutate(Type = ifelse(str_detect(Document, "NDC|[Nn]ationally [Dd]etermined [Cc]ontributions|[Cc]ontribución(es)? [Dd]eterminadas? a [Nn]ivel [Nn]acional(es)?"), "NDC targets", 
                       ifelse(str_detect(Document, "NBTs?|NBSAP|MNBs?|EPANB|CBD|National Biodiversity|Nacional de Biodiversidad"), "National Biodiversity Targets", 
                              "Other targets")))

# Check #8 (number of "Types") -------------------------------------------------
if (length(setdiff(unique(df$Type), c("NDC targets", "National Biodiversity Targets", "Other targets"))) == 0) {
  message('[√] All types are represented')
} else {
  View(df)
  stop('>>> ATTENTION <<<\nAt least one type - NBT, NDC, Others - is missing!')
}
########################### Country changes (start) ############################
# ...
############################ Country changes (end) #############################

# Check #9 ("odd" characters) --------------------------------------------------
#bad_cols <- names(df)[sapply(df, function(col) {is.character(col) && any(str_detect(col, "[^[:alnum:][:punct:]\\s$]"))})]
#if (length(bad_cols) > 0) {View(df)
#  menu(c("Yes", "No"), title = paste0(">> WARNING <<\nThese columns contain unexpected characters: ", paste(bad_cols, collapse = ", ")), ".\nHave you taken note of this?")
#} else {message("[√] Columns seem void of odd characters.")}
pattern <- if (lang == languages[1]) {
  "[^\\p{ASCII}]" # test "[^\\p{L}\\p{N}\\p{P}\\p{Zs}\\p{Sm}\\p{Sc}]"? \p{L} for letters, \p{N} for numbers, \p{P} for punctuation, \p{Zs} for space separators, \p{Sm} for math, \p{Sc} for currency, ...
} else if (lang == languages[2]) {
  "[^\\p{ASCII}áéíóúüÁÉÍÓÚÜñÑ¿¡]"
} else if (lang == languages[3]) {
  "[^\\p{ASCII}âàéêèëîïôúûùüÿœæçÂÀÉÊÈËÎÏÔÚÛÙÜŸŒÆÇ«»]"
}
df <- df %>% 
  mutate(`Odd` = ifelse((str_detect(`Target Text`, pattern) == TRUE | 
                           str_detect(`Target Text`, "�") == TRUE), 1, 0))
if (sum(df$Odd) > 0) {
  View(df %>% 
         select(`Target Text`, Odd) %>% 
         filter(Odd == 1) %>% 
         mutate(Odd = str_extract_all(`Target Text`, pattern)))
  menu(c("Yes", "No"), title = ">> WARNING <<\nThese target texts contain unexpected characters.\nHave you had a proper look?")
} else {
  message("[√] Columns seem void of odd characters.")
}
# if there are any odd characters (√Ç¬†, â€“, Ã©, ¤, Ã±, ...), consider using: iconv(df$, from = "latin1", to = "UTF-8")

################################ Notes (start) #################################
# Tanzania: ≥, -, ’, “, ”, ≈, ₂; [√]
# Uzbekistan: “, ”, ’; [√]
# Dominican Republic: –; [√]
# Namibia: ; [?]
################################ Notes (end) ###################################

# <<<<<<<<<<<<<<<<<<<<<<<<< HERE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Namibia ----
if (cty == "namibia") {
  df_list <- split(df, df$Document)
  df_list[[1]] <- df_list[[1]] %>% 
    mutate(tmp = `Target Name`, 
           `Target Name` = `Target Text`, 
           `Target Text` = tmp) %>% 
    select(-tmp) %>% 
    group_by(`Target Text`) %>% 
    mutate(`Target Name` = paste0(`Target Name`, " ", row_number())) %>% 
    ungroup()
  df_list[[2]] <- df_list[[2]] %>% 
    mutate(`Target Text` = substr(`Target Text`, 
                                  str_locate(df_list[[2]]$`Target Text`, "\\. ")[, 2], 
                                  nchar(`Target Text`)), 
           `Target Text` = str_trim(`Target Text`))
  df <- bind_rows(df_list, .id = "Document")
  
}
# <<<<<<<<<<<<<<<<<<<<<<<<< HERE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

df <- df %>% select(-Odd)

#===============================================================================
# SAVING
#===============================================================================
write_xlsx(list("targets" = df), # better than write.xlsx(), but doesn't allow for specific encoding (should't be a problem as write_xlsx() does "UTF-8" by default)
           path = paste0("../data_", str_replace(tolower(cty), "\\s", "_"), "_", date, ".xlsx"))
