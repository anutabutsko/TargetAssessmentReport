# Guidelines === === === === === === === === === === === === === === === === ===
# Place this script in a folder/directory named "original" alongside the 
# original data sent by the country of interest; this "original" file/directory
# should reside within another folder lowercase named after the country, e.g.:
# namibia > original
# === === === === === === === === === === === === === === === === === === === ==

# Packages ----------------------------------------------------------------
pacman::p_load("tidyverse", "knitr", "stringr", "readr", 
               "openxlsx", "writexl", "readxl", "magrittr")

# Data import -------------------------------------------------------------
cty <- "Tanzania"
setwd(paste0("./data/", tolower(cty)))
data <- list.files(pattern = "\\.(csv|xlsx)$", full.names = TRUE)

# Encoding === === === === === === === === === === === === === === === === === =
# "UTF-8" is the most widely used, more modern, perfect for English;
# "latin1" is "UTF-8" + (á, à, é, ê, ó, ô, ú, ...), perfect for Latin languages;
# "windows-1252" is "latin1" + (ß, ü, ö, ä, ...), perfect for German & EEuropean languages.
# === === === === === === === === === === === === === === === === === === === ==
if (substr(data, str_locate(data, "\\.[a-z]{3,4}"), nchar(data)) == ".csv") {
  #df <- read.csv(data, fileEncoding = "UTF-8")
  df <- read_csv(data, locale = locale(encoding = "windows-1252"))
} else if (substr(data, str_locate(data, "\\.[a-z]{3,4}"), nchar(data)) == ".xlsx") {
  sheets <- excel_sheets(data)
  #df <- read.xlsx(data, sheet = sheets)
  #df <- read_xlsx(data, sheet = sheets)
  df <- read_excel(data, sheet = sheets)
}

# Columns ------------------------------------------------------------------
df <- df %>% 
  # removes index column (failed or not)
  select(-any_of(c("X", "index"))) %>% 
  select(where(~ !all(is.na(.))))

rename_cols <- function(name) {
  case_when(
    str_detect(name, "[Cc]ountry") ~ "Country", 
    str_detect(name, "[Tt]arget") & str_detect(name, "[Nn]ame") ~ "Target Name", 
    str_detect(name, "[Tt]arget") & str_detect(name, "[Tt]ext") ~ "Target Text", 
    str_detect(name, "[Tt]heme") | str_detect(name, "[Cc]onvention") ~ "Convention", 
    str_detect(name, "(?i)URL") ~ "Source", 
    str_detect(name, "[Ss]ource") ~ "Document", 
    TRUE ~ name
  )
}

df <- df %>% 
  rename_with(rename_cols, .cols = everything())

# Data tweaks -------------------------------------------------------------
df <- df %>%  
  # eliminates empty rows
  filter(!if_all(everything(), ~ is.na(.) | . == "")) %>% 
  # removes leading and laggin white spaces
  mutate(`Target Text` = str_trim(`Target Text`), 
         `Target Name` = str_trim(`Target Name`), 
         `Document` = str_trim(`Document`)) %>% 
  # removes double or triple consecutive white spaces
  mutate(`Target Text` = str_replace_all(`Target Text`, "\\s+", " ")) %>% 
  # tries to create a simple acronym for the name of the document
  mutate(Doc = str_replace_all(Document, "[^A-Z]", ""))

df <- df %>% 
  #mutate(`Odd` = ifelse(str_detect(`Target Text`, "[^A-Za-z0-9 %/.,;:!?()\\-']") == TRUE, 1, 0))
  mutate(`Odd` = ifelse((str_detect(`Target Text`, "[^\\p{ASCII}]") == TRUE | 
                           str_detect(`Target Text`, "�") == TRUE), 1, 0))
df %>% 
  select(`Target Text`, Odd) %>% 
  filter(Odd == 1) %>% 
  mutate(Odd = str_extract_all(`Target Text`, "[^\\p{ASCII}]")) %>% 
  unnest(Odd)

### Country changes ###
# Namibia (NBSAP-NDC, 2025) ----
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
# Country (, ) ----
# ...
### Country changes ###
df <- df %>% select(-Odd)

# Extra info --------------------------------------------------------------------
date <- format(Sys.Date(), "%d%b%y")
date <- ifelse(substr(date, 1, 1) == "0", substr(date, 2, nchar(date)), date)

cty <- str_locate_all(dirname(getwd()), "/")[[1]]
country <- substr(dirname(getwd()), cty[nrow(cty), 1]+1, nchar(dirname(getwd())))

# Saving ------------------------------------------------------------------
write_xlsx(list("tatgets" = df), path = paste0("../data_", country, "_", date, ".xlsx"))
