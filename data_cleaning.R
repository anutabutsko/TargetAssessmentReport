# Search (ctr+F)"[Update]" for improvements

#===============================================================================
# PACKAGES 
#===============================================================================
pacman::p_load(tidyverse, knitr, stringr, readr, rvest, 
               openxlsx, writexl, readxl, magrittr, 
               countries, hunspell)

#===============================================================================
# DATA IMPORT 
#===============================================================================
# Setup ------------------------------------------------------------------------
cty <- readline(prompt = "Country name: ")

date <- format(Sys.Date(), "%d%b%y")
date <- ifelse(substr(date, 1, 1) == "0", 
               substr(date, 2, nchar(date)), 
               date)

languages <- c("English", "Spanish", "French", "German", "Russian", "Portuguese") # add more languages if/when necessary
df_lang <- read_html("https://en.wikipedia.org/wiki/List_of_official_languages_by_country_and_territory") %>% html_table(fill = TRUE) %>% .[[2]]
df_lang <- df_lang %>% 
  filter(grepl(paste0("^", cty), df_lang$`Country/Region`))
message(paste0(cty, 
              "\n", colnames(df_lang)[3], ": ", gsub("\n", ", ", df_lang[1, 3]), 
              "\n", colnames(df_lang)[4], ": ", gsub("\n", ", ", df_lang[1, 4]), 
              "\n", colnames(df_lang)[5], ": ", gsub("\n", ", ", df_lang[1, 5]), 
              "\n", colnames(df_lang)[6], ": ", gsub("\n", ", ", df_lang[1, 6]), 
              "\n", colnames(df_lang)[7], ": ", gsub("\n", ", ", df_lang[1, 7]), 
              collapse = ", "))
lang <- menu(languages, 
             title = paste0("On the one hand, Namibia's official language is English, ", 
                           "but targets mention the city 'Lüderitz' (ex-German colony), ", 
                           "\n", 
                           "so German encoding works best; on the other, ", 
                           "Uzbekistan's official language is Russian, ", 
                           "but they sent targets in English.", "\n\n", 
                           "Look at the references above and select ", 
                           "the country data language (ideas in case the encoding fails):"))
lang <- languages[lang]

mrgd <- menu(c("Yes", "No"),  # make this into an automation with fill()? [Update]
             title = paste0("Does the country data contain any merged cells?", "\n", 
                            "If there are merged cells, read_excel() will un-merge them ", 
                            "and leave NAs,\napart from the top-left cell - ", 
                            "which will contain the original value."))


# Extra ------------------------------------------------------------------------
`%not_in%` <- negate(`%in%`)


# Path and file ----------------------------------------------------------------
#setwd("../../../../")
setwd(paste0("data/countries/", str_replace(tolower(cty), "\\s", "_"), "/original"))

data <- list.files(pattern = "\\.(csv|xlsx)$", full.names = TRUE)

# Encoding ---------------------------------------------------------------------
#'guess_encoding()' can be used if all else fails
if (lang == languages[1]) {
  # most widely used, more modern, perfect for English (ASCII is a subset of UTF-8)
  encod <- "UTF-8"; lang_cd <- "en"
} else if (lang == languages[2]) {
  # "UTF-8" + (á, à, é, ê, ó, ô, ú, ...), perfect for Latin languages (“ISO-8859-1”, “ISO-8859-15”, “ISO-8859-2”)
  encod <- "latin1"; lang_cd = "es"
} else if (lang == languages[3]) {
  # "UTF-8" + (á, à, é, ê, ó, ô, ú, ...), perfect for Latin languages (“ISO-8859-1”, “ISO-8859-15”, “ISO-8859-2”)
  encod <- "latin1"; lang_cd = "fr"
} else if (lang == languages[4] | lang == "E. European") {
  # "latin1" + (ß, ü, ö, ä, …), perfect for German & E. Europe
  encod <- "windows-1252"
} else if (lang == "C. European") {
  encod <- "windows-1250"
} else if (lang == "Russian") {
  # Cyrilic, Slavic languages
  encod <- "windows-1251"
} else if (lang == "Arabic") {
  # (“ISO-8859-6”)
  encod <- "windows-1256"
} 

# Read-in files ----------------------------------------------------------------
if (substr(data, str_locate(data, "\\.[a-z]{3,4}"), nchar(data)) == ".csv") {
  data <- substr(data, 3, nchar(data))
  df <- read_csv(data, 
                 locale = locale(encoding = encod)) # read_csv() is better than read.csv()
} else if (substr(data, str_locate(data, "\\.[a-z]{3,4}"), nchar(data)) == ".xlsx") {
  data <- substr(data, 2, nchar(data))
  sheets <- excel_sheets(paste0(getwd(), data))
  # select sheet/tab name
  sheet_ref <- menu(sheets, 
                    title = "Select the country data sheet/tab:")
  sheet <- sheets[sheet_ref]
  df <- read_excel(paste0(getwd(), data), sheet = sheet) # read_excel() is better than read.xlsx()/read_xlsx() and understands encoding automatically (!)
} else {
  stop("The file's format is neither '.xlsx' nor '.csv'")
}


#===============================================================================
# DATA TWEAKS
#===============================================================================

# STRUCTURE: Columns -----------------------------------------------------------
colnames(df)
menu(c("Yes", "No"), title = ">>> ATTENTION <<<\nHave you had a proper look at the column names (right above)?\n(There should be one referencing each of: country name, target name and text, document name and URL/source, and theme)")
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
} else if (cty == "Panama") {
  df <- df %>% 
    mutate(`...9` = ifelse(!is.na(`...9`), NA, `...9`))
} else if (cty == "Colombia") {
  df <- df %>% 
    rename(`Nombre Meta` = `Meta nacional de Colombia`) %>% 
    select(-`Meta Kunming Montreal`) %>% 
    mutate(across(everything(), ~ ifelse(is.na(`Texto de la Meta`) & is.na(`Nombre Meta`), NA, .)))
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

# STRUCTURE: Rows --------------------------------------------------------------
# Removes empty rows
df <- df %>% 
  filter(!if_all(everything(), ~ is.na(.) | . == ""))
########################### Country changes (start) ############################
if (cty == "Tanzania") {
  df <- df[-c(22, 23, 60, 75, 86, 87, 93, 99, 105, 111, 117, 123, 129, 135, 147), ]
}
############################ Country changes (end) #############################

# PARAMS: country name ---------------------------------------------------------
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

# PARAMS: country name language ------------------------------------------------
df <- df %>% 
  mutate(Country = country_name(cty, to = "name_en"))
if (cty == unique(df$Country)) {
  message("[√] Country name seems to be correct, in English!")
} else {
  message(paste0("Seems like '", cty, "' is not the same as '", unique(df$Country), "'"))
}
########################### Country changes (start) ############################
if (cty == "Tanzania") {
  # Keeps name simple
  df <- df %>% mutate(Country = substr(Country, 1, str_locate(Country, ",")-1))
}
############################ Country changes (end) #############################

# TEXT: NAs --------------------------------------------------------------------
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
} else if (cty == "Panama") {
  df$Sector[110:114] <- "Tierras"
} else if (cty == "Lebanon") { 
  df <- df %>% 
    mutate(Source = "")
}
############################ Country changes (end) #############################

# STRUCTURE: swapped target name and text --------------------------------------
if (all(nchar(df$`Target Name`) < nchar(df$`Target Text`)) == "FALSE") {
  View(df %>% 
         filter(nchar(df$`Target Name`) > nchar(df$`Target Text`)))
  menu(c("Yes", "No"), title = ">> WARNING <<\nLooks like some Target Names and Target Texts are swapped!\nLook at the View() pane opened above.\n(Pro tip: sometimes the target text just is smaller than the target name,\nso look at all the targets in any document referenced in the View() pane above)\n\nWere you able to identify why?")
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
} else if (cty == "Namibia") {
  df$`Target Name`[25] # jump to "TEXT: Odd characters" ("L�deritz")
  df_aux <- df %>% 
    filter(Document == "LT-LEDS") %>% 
    mutate(tmp = `Target Name`, 
           `Target Name` = `Target Text`, 
           `Target Text` = tmp) %>% 
    select(-tmp)
  df <- df %>% 
    filter(Document != "LT-LEDS")
  df <- rbind(df, df_aux)
}
############################ Country changes (end) #############################

# STRUCTURE: empty cells -------------------------------------------------------
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
    unique() # same as the docs specified in ø, so this '' are normal
}
############################ Country changes (end) #############################

# TEXT: unique target names ----------------------------------------------------
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
} else if (cty == "Namibia") {
  df_aux <- df %>% 
    filter(Document == "LT-LEDS") %>% 
    group_by(`Target Name`) %>% 
    mutate(`Target Name` = paste0(`Target Name`, " ", row_number())) %>% 
    ungroup()
  df <- df %>% 
    filter(Document != "LT-LEDS")
  df <- rbind(df, df_aux)
} else if (cty == "Panama") {
  # Not really a problem; will be corrected in ∑
} else if (cty == "Colombia") {
  df <- df %>% 
    mutate(`Target Name` = c('Meta 1 Acción estratégica 1', 'Meta 1 Acción estratégica 2', 'Meta 1 Acción estratégica 3', 
                             'Meta 1 Acción estratégica 4', 'Meta 1 Acción complementaria 1', 'Meta 1 Acción complementaria 3', 
                             'Meta 1 Acción complementaria 4', 'Meta 1 Condición habilitante 1', 'Meta 1 Condición habilitante 2', 
                             'Meta 1 Condición habilitante 13', 'Meta 1 Condición habilitante 14', 'Meta 1 Medios de implementación 1', 
                             'Meta 1 Medios de implementación 2', 'Meta 1 Medios de implementación 11', 'Meta 1 Acción estratégica 5', 
                             'Meta 1 Condición habilitante 3', 'Meta 1 Condición habilitante 4', 'Meta 1 Condición habilitante 5', 
                             'Meta 1 Condición habilitante 6', 'Meta 1 Condición habilitante 16', 'Meta 1 Medios de implementación 3', 
                             'Meta 1 Medios de implementación 4', 'Meta 1 Medios de implementación 5', 'Meta 1 Medios de implementación 12', 
                             'Meta 1 Medios de implementación 13', 'Meta 1 Medios de implementación 16', 'Meta 1 Medios de implementación 17', 
                             'Meta 1 Acción estratégica 6', 'Meta 1 Acción complementaria 6', 'Meta 1 Condición habilitante 18', 
                             'Meta 1 Medios de implementación 6', 'Meta 1 Medios de implementación 7', 'Meta 1 Medios de implementación 8', 
                             'Meta 1 Medios de implementación 14', 'Meta 1 Acción complementaria 7', 'Meta 1 Condición habilitante 12', 
                             'Meta 1 Medios de implementación 9', 'Meta 1 Medios de implementación 10', 'Meta 1 Acción complementaria 8', 
                             'Meta 1 Condición habilitante 9', 'Meta 1 Condición habilitante 11', 'Meta 2 Acción estratégica 1', 
                             'Meta 2 Acción complementaria 1', 'Meta 2 Condición habilitante 1', 'Meta 2 Condición habilitante 2', 
                             'Meta 2 Condición habilitante 5', 'Meta 2 Medios de implementación 6', 'Meta 2 Medios de implementación 2', 
                             'Meta 2 Acción estratégica 3', 'Meta 2 Acción complementaria 2', 'Meta 2 Acción complementaria 4', 
                             'Meta 2 Medios de implementación 4', 'Meta 2 Acción complementaria 5', 'Meta 2 Acción complementaria 6', 
                             'Meta 2 Acción complementaria 7', 'Meta 2 Acción complementaria 8', 'Meta 2 Condición habilitante 8', 
                             'Meta 2 Condición habilitante 11', 'Meta 2 Acción complementaria 10', 'Meta 3 Condición habilitante 15', 
                             'Meta 3 Acción estratégica 4', 'Meta 3 Acción complementaria 2', 'Meta 3 Condición habilitante 11', 
                             'Meta 3 Acción estratégica 5', 'Meta 3 Acción complementaria 9', 'Meta 4 Acción estratégica 1', 
                             'Meta 4 Acción complementaria 1', 'Meta 4 Acción estratégica 6', 'Meta 4 Acción complementaria 3', 
                             'Meta 4 Acción complementaria 4', 'Meta 4 Condición habilitante 6', 'Meta 4 Condición habilitante 7', 
                             'Meta 4 Condición habilitante 8', 'Meta 4 Medios de implementación 2', 'Meta 5 Acción estratégica 1', 
                             'Meta 5 Acción complementaria 1', 'Meta 5 Acción complementaria 2', 'Meta 5 Condición habilitante 2', 
                             'Meta 5 Condición habilitante 11', 'Meta 5 Condición habilitante 4', 'Meta 5 Condición habilitante 9', 
                             'Meta 5 Acción estratégica 4', 'Meta 5 Condición habilitante 8', 'Meta 5 Medios de implementación 3', 
                             'Meta 5 Medios de implementación 4', 'Meta 6 Acción estratégica 1', 'Meta 6 Acción estratégica 2', 
                             'Meta 6 Acción estratégica 3', 'Meta 6 Acción complementaria 1', 'Meta 6 Acción complementaria 3', 
                             'Meta 6 Acción complementaria 4', 'Meta 2', 'Meta 3', 'Meta 4', 'Meta 10', 'Meta 11', 'Meta 17', 'Meta 18', 
                             'Meta 19', 'Meta 21', 'Meta 22', 'Meta 23', 'Meta 24', 'Meta 27', 'Meta 28', 'Meta 29', 'Meta 30', 
                             'Medida Sectoral 8', 'Medida Sectoral 9', 'Medida Sectoral 10', 'Medida Sectoral 26', 'Medida Sectoral 31', 
                             'Meta Tecnologia 10', 'Meta Tecnologia 17.2', 'Meta Tecnologia 18', 'Meta Tecnologia 21.4', 'Meta Tecnologia 21.5', 
                             'Meta Tecnologia 22.1', 'Meta Tecnologia 22.2', 'Meta Tecnologia 22.3', 'Meta Tecnologia 22.4', 'Meta Tecnologia 24', 
                             'Meta Tecnologia 27', 'Meta Tecnologia 28', 'Meta Tecnologia 29.1', 'Meta Tecnologia 29.2', 'Meta Capacidades 22.2', 
                             'Meta Capacidades 27.2', 'Meta Capacidades 28.1', 'Meta Capacidades 28.2', 'Meta Capacidades 29.1', 
                             'Apoyo Financiero 30.1', 'Apoyo Financiero 30.2', 'Apoyo Financiero 30.3', 'Apoyo Financiero 30.4', 'Opción 2.6', 
                             'Opción 2.7', 'Opción 2.8', 'Opción 2.9', 'Opción 3.10', 'Opción 3.11', 'Opción 3.12', 'Opción 3.13', 'Opción 5.18', 
                             'Opción 5.19', 'Opción 5.20', 'Opción 5.21', 'Opción 5.22', 'Opción 5.23', 'Opción 5.24', 'Opción 6.29', 'Opción 8.45'))
}
############################ Country changes (end) #############################

# TEXT: remove target name elements from target text ---------------------------
df <- df %>% 
  mutate(remove = str_trim(gsub("[A-Za-z]", "", `Target Name`))) %>% 
  mutate(check = str_detect(`Target Text`, fixed(remove)))

if (any(df$check) == TRUE) {
  View(select(df, `Target Text`, `Target Name`, remove, check) %>% filter(check == TRUE))
  message(">> WARNING <<\nIt seems like some target descriptions/texts reference the numerical part of its corresponding target name. \nCheck the View() pane opened above.")
  menu(c("Yes", "No"), title = "Have you taken note of this?")
} else {
  message("[√] It doesn't seem like any target description/text references the its corresponding target name.")
}

########################### Country changes (start) ############################
df <- df %>% select(-c(remove, check))
############################ Country changes (end) #############################

# TEXT: URLs -------------------------------------------------------------------
df <- df %>% 
  mutate(url = ifelse((str_detect(tolower(Document), "ort|online reporting tool") | 
                         str_detect(tolower(Source), "ort|online reporting tool")), 1, 0))

if (sum(df$url) != 0) {
  View(filter(df, url == 1))
  message(">> WARNING <<\nSeems like the CBD's ORT is referenced as a source.\nTake note of this and make chenges if needed, below.")
  menu(c("Yes", "No"), title = "Have you taken note of this?")
}

urls <- df %>% 
  select(Document, Source) %>% unique()

if (length(unique(urls$Document)) != nrow(urls)) {
  View(filter(urls, Document %in% names(table(Document))[table(Document) >= 2]))
  message(">> WARNING <<\nSome documents seem to have multiple URLs. \nCheck what's going on in column 'Source' in the View() pane opened above.")
  menu(c("Yes", "No"), title = "Have you taken note of this?")
} else {
  View(urls)
  message("[√] Seems like each document has a single URL reference")
  menu(c("Yes", "No"), title = paste0("Just check above: are there ", length(unique(urls$Document)), " documents?"))
}
########################### Country changes (start) ############################
if (cty == "Tanzania") {
  df <- df %>% 
    mutate(Source = ifelse(Document == "National Biodiversity Target via Online Reporting Tool", 
                           filter(df, Document %in% names(table(Document))[table(Document) >= 2])$Source[3], 
                           Source)) # other documents share a same link, so it's still normal that Check #7 would not clear
} else if (cty == "Uzbekistan") {
  df <- df %>% 
    mutate(Source = ifelse(Document == "BTR1 of Uzbekistan", 
                           urls$Source[32], 
                           Source), 
           Source = ifelse(Document == "CBD Online Reporting Tool", 
                           urls$Source[1], 
                           Source))
} else if (cty == "Dominican Republic") {
  df <- df %>% 
    mutate(Document = ifelse(grepl("^Estrategia", Document), 
                             urls$Document[2], 
                             Document))
} else if (cty == "Panama") { # ∑
  df <- df %>% 
    mutate(Source = ifelse(str_detect(Source, "Biodiversidad"), "https://www.undp.org/sites/g/files/zskgke326/files/migration/pa/Estrategia-Nacional-Biodiversidad-2050.pdf", Source), 
           Source = ifelse(str_detect(Source, "Tierras"), "https://sinia.gob.pa/estrategia-nacional-de-neutralidad-de-degradacion-de-tierras-informe-final/", Source))
  tmp_doc <- df$Document[85]
  tmp_src <- df$Source[85]
  df <- df %>% 
    mutate(Document = ifelse(Convention == "Clima", tmp_doc, Document), 
           Source = ifelse(Convention == "Clima", tmp_src, Source))
} else if (cty == "Lebanon") {
  df <- df %>% 
    mutate(url = ifelse(Document == "CBD Online Reporting Tool", "https://ort.cbd.int/", "url")) # "from the CBD's Online Reporting Tool (ORT)"
} else if (cty == "Colombia") {
  df <- df %>% 
    mutate(Document = ifelse(Convention == "Biodiversidad", "Plan de acción de biodiversidad de Colombia al 2030", Document), 
           Document = ifelse(str_detect(Document, "NDC"), "Actualización de la Contribuición Determinada a Nivel Nacional", Document))
}

df <- df %>% select(-url)
############################ Country changes (end) #############################

# TEXT: spacing ----------------------------------------------------------------
df <- df %>%  
  # eliminates empty rows (repeated, but just to be safe!)
  filter(!if_all(everything(), ~ is.na(.) | . == "")) %>% 
  # removes leading and lagging white spaces
  mutate(`Target Text` = str_trim(`Target Text`), 
         `Target Name` = str_trim(`Target Name`), 
         Document = str_trim(Document)) %>% 
  # removes multiple consecutive white spaces
  mutate(`Target Text` = str_squish(`Target Text`)) %>% # better than str_replace_all(`Target Text`, "\\s+", " ")
  # removes "non-breaking", "thin", "zero-width", "narrow no-break", "medium mathematical" and "ideographical" spaces
  mutate(`Target Text` = str_replace_all(`Target Text`, "[\u00A0\u2000-\u200D\u202F\u205F\u3000]", " "))

# VARIABLES: country name in Document ------------------------------------------
if (any(str_detect(df$Document, paste0("(?i)", country_name(cty, to = paste0("name_", lang_cd))))) == TRUE) {
  print(unique(df$Document[str_detect(df$Document, paste0("(?i)", country_name(cty, to = paste0("name_", lang_cd))))]))
  message(">> WARNING <<\nThe document name(s) above containt(s) the country name; it should be removed.")
  menu(c("Yes", "No"), title = "Have you taken note of this?")
} else {
  unique(df$Document)
  message("[√] Seems like the country name does not show up in any of the documents provided!")
}
########################### Country changes (start) ############################
if (cty == "Panama") {
  df <- df %>% 
    mutate(Document = ifelse(Document == unique(df$Document[str_detect(df$Document, paste0("(?i)", country_name(cty, to = paste0("name_", lang_cd))))]), 
                             substr(Document, 1, (nchar(Document) - 15)), Document))
} else if (cty == "Colombia") {
  df <- df %>% 
    mutate(Document = ifelse(str_detect(Document, "Colombia"), "Plan de acción de biodiversidad", Document))
}
############################ Country changes (end) #############################

# VARIABLES: acronyms in Document ----------------------------------------------
if (any(str_detect(df$Document, "[A-Z]{2,}")) == TRUE) {
  print(unique(df$Document[str_detect(df$Document, "[A-Z]{2,}")]))
  message(">> WARNING <<\nThe document name(s) above containt(s) acronyms; these should be removed.\nBut keep notes if the acronym is NBSAP/EPANB/SPANB, NDC/CDN, and similars!")
  menu(c("Yes", "No"), title = "Have you taken note of this?")
} else {
  unique(df$Document)
  message("[√] Seems like no acronym shows up in any of the documents provided!")
}
########################### Country changes (start) ############################
if (cty == "Panama") {
  df <- df %>% 
    mutate(Document = ifelse(Document == unique(df$Document[str_detect(df$Document, "[A-Z]{2,}")]), 
                             str_replace_all(Document, "\\([^)]*\\)", ""), Document))
} else if (cty == "Lebanon") {
  df <- df %>% 
    mutate(Document = ifelse(Document == "NDC", "Draft Nationally Determined Contributions", Document))
}
############################ Country changes (end) #############################

# VARIABLES: Document acronym and Target Type ----------------------------------
if (lang == languages[1]) {
  trm_nat <- "National Biodiversity|CBD"; acr_nat <- "NBSAP"; trg_nat <- "NBT"
  trm_cli <- "[Nn]ationally [Dd]etermined|[Dd]etermined [Cc]ontributions"; acr_cli <- "NDC"; trg_cli <- "NDC targets"
  trg_oth <- "Other targets"
} else if (lang == languages[2]) {
  trm_nat <- "Nacional de Biodiversidad|[Bb]iodiversidad"; acr_nat <- "EPANB"; trg_nat <- "MNB"
  trm_cli <- "[Cc]ontribución(es)? [Dd]eterminadas?|[Dd]eterminadas? a [Nn]ivel [Nn]acional(es)?"; acr_cli <- "CDN"; trg_cli <- "Metas de las CDN"
  trg_oth <- "Otras metas"
} else if (lang == languages[3]) {
  trm_nat <- "Nationaux pour la Biodiversité"; acr_nat <- "SPANB"; trg_nat <- "CNB"
  trm_cli <- "[Cc]ontributions? [Dd]éterminé(es)?|[Dd]éterminé(es)? au [Nn]iveau [Nn]ational"; acr_cli <- "CDN"; trg_cli <- "Cibles des CDN"
  trg_oth <- "Autres cibles"
}

df <- df %>% 
  # creates a simple acronym for the name of the document (Doc)
  mutate(Doc = ifelse(str_detect(Document, trm_nat), acr_nat, 
                      ifelse(str_detect(Document, trm_cli), acr_cli, 
                             str_replace_all(Document, "[^A-Z]", "")))) %>% 
  # creates the "target types" (NDC Targets, National Biodiversity Targets (NBTs) and Other targets)
  mutate(Type = ifelse(str_detect(Document, trm_nat), trg_nat, 
                       ifelse(str_detect(Document, trm_cli), trg_cli, 
                              trg_oth)))

if (length(setdiff(c(trg_cli, trg_nat, trg_oth), unique(df$Type))) == 0) {
  message('[√] All types are represented')
  message("... but just for safety: does it seem like the target types and document acronyms are correct?\nMake country-specific changes below if not.")
  View(select(df, Document, Doc, Type) %>% unique())
} else {
  View(df)
  stop(paste0('>>> ATTENTION <<<\nThere seems to be no '), setdiff(c(trg_cli, trg_nat, trg_oth), unique(df$Type)))
}

########################### Country changes (start) ############################
if (cty == "Dominican Republic") {
  df <- df %>% 
    mutate(Type = ifelse(grepl("^Estrategia", Document), 
                         setdiff(c("NDC targets", "National Biodiversity Targets", "Other targets"), unique(df$Type)), 
                         Type))
} else if (cty == "Colombia") {
  df <- df %>% 
    mutate(Doc = ifelse(Doc == "E", "E50", Doc))
}
############################ Country changes (end) #############################

# TEXT: Odd characters  --------------------------------------------------------
# Consider using: iconv(df$, from = "latin1", to = "UTF-8") if these sort of patterns emerge: (√Ç¬†, â€“, Ã©, ¤, Ã±, ...)
#bad_cols <- names(df)[sapply(df, function(col) {is.character(col) && any(str_detect(col, "[^[:alnum:][:punct:]\\s$]"))})]
#if (length(bad_cols) > 0) {View(df)
#  menu(c("Yes", "No"), title = paste0(">> WARNING <<\nThese columns contain unexpected characters: ", paste(bad_cols, collapse = ", ")), ".\nHave you taken note of this?")
#} else {message("[√] Columns seem void of odd characters.")}
if (lang == languages[1]) {
  pattern <- "[^\\p{ASCII}]" # test "[^\\p{L}\\p{N}\\p{P}\\p{Zs}\\p{Sm}\\p{Sc}]"? \p{L} for letters, \p{N} for numbers, \p{P} for punctuation, \p{Zs} for space separators, \p{Sm} for math, \p{Sc} for currency, ...
} else if (lang == languages[2]) {
  pattern <- "[^\\p{ASCII}áéíóúüÁÉÍÓÚÜñÑ¿¡]"
} else if (lang == languages[3] | lang == languages[4]) {
  pattern <- "[^\\p{ASCII}âàéêèëîïôúûùüÿœæçÂÀÉÊÈËÎÏÔÚÛÙÜŸŒÆÇ«»]"
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
  message("[√] Target text seems void of odd characters.")
}
########################### Country changes (start) ############################
# [√] Tanzania: ≥, -, ’, “, ”, ≈, ₂
# [√] Uzbekistan: “, ”, ’
# [√] Dominican Republic: –
# [X] Namibia: Jump to "STRUCTURE: swapped target name and text"... aaaand it's a loop, a quick Google indicates the string is "Lüderitz" so let's just restart with German as encoding, rather than English 
# [√] Panama: “; ”
# [√] Lebanon: “; ”; ●
# [√] Colombia: –, ´, “, ”
df <- df %>% select(-Odd)
############################ Country changes (end) #############################

# TEXT: Odd words --------------------------------------------------------------
#if the language seems to be missing, go to Tools > General Options > Spelling > 
# Main dictionary language: Install More Dictionaries...
if (lang_cd == "en") {dict = "us"} else {dict = lang_cd}

df$typos <- lapply(df$`Target Text`, function(x) {
  hunspell(x, dict = dictionary(paste(lang_cd, toupper(dict), sep = "_")))
})

df$suggestions <- lapply(df$typos, function(x) {
  lapply(x, hunspell_suggest, dict = dictionary(paste(lang_cd, toupper(dict), sep = "_")))
})

if (all(sapply(df$typos, function(x) identical(x, list(character(0))))) == FALSE) {
  View(select(df, `Target Name`, `Target Text`, Doc, typos, suggestions)[sapply(df$typos, function(x) length(x[[1]]) > 0), ])
  message("Check above for (1) typos - in which case, consider the suggestions for replacements/corrections;\n(2) potential keywords/acronyms that might require translation/replacement - in which case, look for meanings\nin the Documents links (below) and add the element and its meaning to the 'terms_{DDMmmYY}.xls' file in the 'data' directory.")
  print(unique(df$Source))
}


########################### Country changes (start) ############################
df <- df %>% select(-c(typos, suggestions))
############################ Country changes (end) #############################

#===============================================================================
# SAVING
#===============================================================================
write_xlsx(list("targets" = df), # better than write.xlsx(), but doesn't allow for specific encoding (should't be a problem as write_xlsx() does "UTF-8" by default)
           path = paste0("../data_", str_replace(tolower(cty), "\\s", "_"), "_", date, ".xlsx"))
