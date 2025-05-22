# Packages ---------------------------------------------------------------------
pacman::p_load("tidyverse", "knitr", "stringr", "readr", 
               "openxlsx", "writexl", "readxl", "magrittr")

# Setup ------------------------------------------------------------------------
cty <- "Uzbekistan" # <================================================= change here!
mrgd <- menu(c("Yes", "No"), title = "Does the country data contain any merged cells?")
# select language
languages <- c("English", "Spanish", "French") # <============================== add here!
lang <- menu(languages, title = "Select the country data language:")
lang <- languages[lang]

setwd(paste0("data/countries/", str_replace(tolower(cty), "\\s", "_"), "/original"))

data <- list.files(pattern = "\\.(csv|xlsx)$", full.names = TRUE)
data <- substr(data, 2, nchar(data))

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
# ... if the language is not clear (or if you want to be safe), use:
#guess_encoding(substr(data, 2, nchar(data)))[1]

# Data import ------------------------------------------------------------------
if (substr(data, str_locate(data, "\\.[a-z]{3,4}"), nchar(data)) == ".csv") {
  df <- read_csv(data, locale = locale(encoding = encod)) # read_csv() is better than read.csv()
} else if (substr(data, str_locate(data, "\\.[a-z]{3,4}"), nchar(data)) == ".xlsx") {
  sheets <- excel_sheets(paste0(getwd(), data))
  # select sheet/tab name
  sheet_ref <- menu(sheets, title = "Select the country data sheet/tab:")
  sheet <- sheets[sheet_ref]
  df <- read_excel(paste0(getwd(), data), sheet = sheet) # read_excel() is better than read.xlsx()/read_xlsx() and understands encoding automatically (!)
} else {
  message("The file's format is neither .xlsx nor .csv")
}
rm(sheets)

########################### Country changes (start) ############################
# Tanzania ----
if (cty == "Tanzania") {
  # properly names the columns & removes duplicated column names and NAs
  cnames <- df[2, ]
  cnames[1] <- "Country"
  colnames(df) <- cnames
  rm(cnames)
  df <- df %>% 
    filter(!grepl("Target Text", .[[2]]), !grepl("Target Name", .[[3]]), 
           !grepl("Source or Document", .[[4]]), !grepl("TargetSource URL", .[[5]]), 
           !grepl("Theme", .[[6]]))
  df <- df %>% 
    filter(!if_all(everything(), ~ is.na(.) | . == ""))
  # ...removes unnecessary "document section separators"
  df <- df %>% 
    filter(if_any(3:6, ~ !is.na(.)))
  # properly add the country name
  df <- df %>% mutate(Country = cty)
  # corrects NA cells that were part of a merged cell
  df[132, 5] <- NA
  df <- df %>% fill(c(2, 4:6), .direction = "down")
  # final adjustments
  df[112:121, 5] <- ""
  # swap Target Text and Target Title for the NDC
  df_aux <- df %>% 
    filter(`Source or Document` == "Tanzania’s NDC (2021)") %>% 
    mutate(tmp = `Target Name`, 
           `Target Name` = `Target Text`) %>% 
    mutate(`Target Text` = tmp) %>% 
    select(-tmp) %>% 
    group_by(`Target Name`) %>% 
    mutate(`Target Name` = paste0(`Target Name`, " ", row_number())) %>% 
    ungroup()
  df <- df %>% 
    filter(`Source or Document` != "Tanzania’s NDC (2021)")
  df <- rbind(df, df_aux)
  rm(df_aux)
  # Removes the country name from the document name
  df <- df %>% 
    mutate(`Source or Document` = gsub("Zanzibar", "", `Source or Document`)) %>% 
    mutate(`Source or Document` = gsub("('s|’s)", "", `Source or Document`))
  # Ensureing the right name for NBTs
  df <- df %>% 
    mutate(`Source or Document` = ifelse(grepl("(National Biodiversity Target)", `Source or Document`), 
                                         "National Biodiversity Target", `Source or Document`))
  # Typos:
  # NCCRS - Objective 2 (Adaptation): "**"
  # NCCRS - Objective 1 (Mitigation): "BAUby"
  # NDC - Overall Resilience & Water Access 2: (urban)/67.7%
  # NDC - Gender Mainstreaming: Indigenous Peoples"
  # NBSAP - Target 2: "2030,ensure"
  # NBSAP - Target 10-1: "2030, Enhanced"
  # NBSAP - Target 10-2: "2030, Agro"
  # NBSAP - Target 11: "2030, Nature"
  # NBSAP - Target 13: "2030, Guidelines"
  # NBSAP - Target 21-2: "2030, Best"
  # NBSAP - Target 23-1: "2030, Informed"

}
# Uzbekistan ----
if (cty == "Uzbekistan") {
  df <- df %>% 
    mutate(`Source or Document...4` = ifelse(`Source or Document...5` == "NDC2.0", 
                                             `Source or Document...5`, 
                                             `Source or Document...4`))
  df <- df[, -c(5, 7)]
  df <- df %>% fill(1, .direction = "down")
}
# {Country} ----
# ...
############################ Country changes (end) #############################

# Column names -----------------------------------------------------------------
df <- df %>% 
  select(-any_of(c("X", "index"))) %>% 
  select(where(~ !all(is.na(.))))

rename_cols <- function(name) {
  case_when(
    str_detect(name, "\\b[Cc]ountry|[Pp]a[ií]s\\b") ~ "Country", # detects "Country", "country", "País", "país", "Pais", "pais", 
    str_detect(name, "\\b[Tt]argets?|[Mn]etas?\\b") & # detects "Target(s)", "target(s)", "Meta(s)", "meta(s)", 
      str_detect(name, "\\b[Nn]ame|[Nn]ombre\\b") ~ "Target Name", # detects "Name", "name", "Nombre", "nombre", 
    str_detect(name, "\\b[Tt]argets?|[Mm]etas?\\b") & # detects "Target(s)", "target(s)", "Meta(s)", "meta(s)", 
      str_detect(name, "\\b[Tt]exto?\\b") ~ "Target Text", # detects "Text", "text", "Texto", "texto", 
    str_detect(name, "\\b[Tt]hemes?|[Tt]emas?\\b") | # detects "Theme(s)", "theme(s)", "Tema(s)", "tema(s)", 
      str_detect(name, "\\b[Cc]onventions?|[Cc]onvenci[oó]n(es)?\\b") ~ "Convention", # detects "Convention(s)", "convention(s)", "Convención(es)", "convención(es)", 
    str_detect(name, "(?i)URL") ~ "Source", # detects "URL", "url", "Url", "UrL", ...
    str_detect(name, "\\b[Ss]ources?|[Ff]uentes?\\b|[Dd]ocuments?|[Dd]ocumentos?") ~ "Document", # detects "Source(s)", "source(s)", "Fuente(s)", "fuente(s)", "Document(s)", "Documento(s)", 
    TRUE ~ name
  )
}

df <- df %>% 
  rename_with(rename_cols, .cols = everything())

# Data tweaks ------------------------------------------------------------------
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

# in case there were merged cells, read-excel() will have un-merged and left NAs behind, apart from the top-left cell
if (mrgd == 1) {
  # any NA is replaced by the value above
  df <- df %>% fill(everything())
}
  
df <- df %>% 
  # removes country names from the Document
  mutate(Document = gsub(cty, "", Document)) %>% 
  mutate(Document = gsub("('s|’s)", "", Document))
  
df <- df %>% 
  # creates a simple acronym for the name of the document (Doc)
  mutate(Doc = str_replace_all(Document, "[^A-Z]", "")) %>% 
  # creates the "target types" (NDC Targets, National Biodiversity Targets (NBTs) and Other targets)
  mutate(Type = ifelse(str_detect(Document, "NDC|[Nn]ationally [Dd]etermined [Cc]ontributions|[Cc]ontribución(es)? [Dd]eterminadas? a [Nn]ivel [Nn]acional(es)?"), "NDC targets", 
                       ifelse(str_detect(Document, "NBTs?|NBSAP|MNBs?|EPANB|CBD|[Bb]iodiversity|[Bb]iodiversidad"), "National Biodiversity Targets", 
                              "Other targets")))

# Checks -----------------------------------------------------------------------
# checks whether there is a single country name
if (length(unique(df$`Country`)) == 1) {
  message('[√] There is a single country name')
} else {
  stop('WARNING: \n[X] There are multiple country names!')
}

# checks whether all of the 3 types of targets are represented
if (length(setdiff(unique(df$Type), c("NDC targets", "National Biodiversity Targets", "Other targets"))) == 0) {
  message('[√] All types are represented')
} else {
  stop('WARNING: \n[X] At least one type - NBT, NDC, Others - is missing!')
}

# checks whether the target names are uniquely identified
if (nrow(df) == length(unique(df$`Target Name`))) {
  message('[√] All target names are uniquely defined (like an identifier)')
} else {
  stop('WARNING: \n[X] Target names are NOT uniquely defined (like an identifier)!')
}

pattern <- if (lang == languages[1]) {
  "[^\\p{ASCII}]"
} else if (lang == languages[2]) {
  "[^\\p{ASCII}áéíóúüÁÉÍÓÚÜñÑ¿¡]"
} else if (lang == languages[3]) {
  "[^\\p{ASCII}âàéêèëîïôúûùüÿœæçÂÀÉÊÈËÎÏÔÚÛÙÜŸŒÆÇ«»]"
}
df <- df %>% 
  # detects odd characters
  mutate(`Odd` = ifelse((str_detect(`Target Text`, pattern) == TRUE | 
                           str_detect(`Target Text`, "�") == TRUE), 1, 0))
# check if there are any odd characters (deal with them in the next "Country changes", below)
View(df %>% 
       select(`Target Text`, Odd) %>% 
       filter(Odd == 1) %>% 
       mutate(Odd = str_extract_all(`Target Text`, pattern)))
# ... if there are any odd characters (√Ç¬†, â€“, Ã©, ¤, Ã±, ...), consider use: 
#iconv(df$, from = "latin1", to = "UTF-8")

################################ Notes (start) #################################
# Tanzania: ≥, -, ’, “, ”, ≈, ₂; [√]
# Dominican Republic: –; [√]
# Uzbekistan: “, ’; [√]
################################ Notes (end) ###################################

########################### Country changes (start) ############################
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
# {Country} ----
# ...
############################ Country changes (end) #############################

df <- df %>% 
  select(-Odd)

# Extra info --------------------------------------------------------------------
date <- format(Sys.Date(), "%d%b%y")
date <- ifelse(substr(date, 1, 1) == "0", substr(date, 2, nchar(date)), date)

# Saving ------------------------------------------------------------------
write_xlsx(list("targets" = df), # better than write.xlsx(), but doesn't allow for specific encoding (should't be a problem as write_xlsx() does "UTF-8" by default)
           path = paste0("../data_", str_replace(tolower(cty), "\\s", "_"), "_", date, ".xlsx"))
