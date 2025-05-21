# Packages ----------------------------------------------------------------
pacman::p_load("tidyverse", "knitr", "stringr", "readr", 
               "openxlsx", "writexl", "readxl", "magrittr")

# Data import -------------------------------------------------------------
cty <- "Dominican Republic" # <================================================= change here!
lang <- "Spanish" # <=========================================================== change here!

setwd(paste0("data/countries/", str_replace(tolower(cty), "\\s", "_"), "/original"))
datas <- list.files(pattern = "\\.(csv|xlsx)$", full.names = TRUE)
data_ref <- menu(datas, title = "Select the correct file:") # <================= select file!
data <- datas[data_ref]
if (lang != "English") {data_tr <- setdiff(datas, data)}

data <- substr(data, 2, nchar(data))
if (lang != "English") {data_tr <- substr(data_tr, 2, nchar(data_tr))}
rm(datas)

# Encoding === === === === === === === === === === === === === === === === === =
# "UTF-8" is the most widely used, more modern, perfect for English;
# "latin1" is "UTF-8" + (á, à, é, ê, ó, ô, ú, ...), perfect for Latin languages;
# "windows-1252" is "latin1" + (ß, ü, ö, ä, …), perfect for German & E. Europe
# === === === === === === === === === === === === === === === === === === === ==
if (substr(data, str_locate(data, "\\.[a-z]{3,4}"), nchar(data)) == ".csv") {
  #df <- read.csv(paste0(getwd(), data), fileEncoding = "UTF-8")
  df <- read_csv(data, locale = locale(encoding = "UTF-8")) # read_csv() is better than read.csv() is
} else if (substr(data, str_locate(data, "\\.[a-z]{3,4}"), nchar(data)) == ".xlsx") {
  sheets <- excel_sheets(paste0(getwd(), data))
  sheet_ref <- menu(sheets, title = "Select a sheet/tab") # <======================= select sheet/tab name
  sheet <- sheets[sheet_ref]
  df <- read_excel(paste0(getwd(), data), sheet = sheet) # read_excel() is better at detecting encoding than read.xlsx() and read_xlsx() are
} else {
  message("The file's format is neither .xlsx nor .csv")
}
rm(sheets)

if (lang != "English") {
  if (substr(data_tr, str_locate(data_tr, "\\.[a-z]{3,4}"), nchar(data_tr)) == ".csv") {
    #df <- read.csv(paste0(getwd(), data), fileEncoding = "UTF-8")
    df_tr <- read_csv(data_tr, locale = locale(encoding = "UTF-8")) # read_csv() is better than read.csv() is
  } else if (substr(data_tr, str_locate(data_tr, "\\.[a-z]{3,4}"), nchar(data_tr)) == ".xlsx") {
    df_tr <- read_excel(paste0(getwd(), data_tr)) # read_excel() is better at detecting encoding than read.xlsx() and read_xlsx() are
  } else {
    message("The file's format is neither .xlsx nor .csv")
  }
}

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
# {Country} ----
# ...
############################ Country changes (end) #############################

# Columns ------------------------------------------------------------------
df <- df %>% 
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
  # removes leading and lagging white spaces
  mutate(`Target Text` = str_trim(`Target Text`), 
         `Target Name` = str_trim(`Target Name`), 
         Document = str_trim(Document)) %>% 
  # removes double or triple consecutive white spaces
  mutate(`Target Text` = str_replace_all(`Target Text`, "\\s+", " "))
  
df <- df %>% 
  # removes country names from the Document
  mutate(Document = gsub(cty, "", Document)) %>% 
  mutate(Document = gsub("('s|’s)", "", Document))
  # creates a simple acronym for the name of the document (Doc)
df <- df %>% 
  mutate(Doc = str_replace_all(Document, "[^A-Z]", "")) %>% 
  # creates the "target types" (NDC Targets, National Biodiversity Targets (NBTs) and Other targets)
  mutate(Type = ifelse(str_detect(Document, "NDC|Nationally Determined Contributions"), "NDC targets", 
                       ifelse(str_detect(Document, "NBT|NBSAP|National Biodiversity Target"), "National Biodiversity Targets", "Other targets")))
  
df <- df %>% 
  #mutate(`Odd` = ifelse(str_detect(`Target Text`, "[^A-Za-z0-9 %/.,;:!?()\\-']") == TRUE, 1, 0))
  mutate(`Odd` = ifelse((str_detect(`Target Text`, "[^\\p{ASCII}]") == TRUE | 
                           str_detect(`Target Text`, "�") == TRUE), 1, 0))

View(df %>% # <================================================================= check if there are any odd characters (deal with them in the next "Country changes", below)
  select(`Target Text`, Odd) %>% 
  filter(Odd == 1) %>% 
  mutate(Odd = str_extract_all(`Target Text`, "[^\\p{ASCII}]")))
# Tanzania: ≥, -, ’, “, ”, ≈, ₂; [√]


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
df <- df %>% select(-Odd)

# Extra info --------------------------------------------------------------------
date <- format(Sys.Date(), "%d%b%y")
date <- ifelse(substr(date, 1, 1) == "0", substr(date, 2, nchar(date)), date)

cty <- str_locate_all(dirname(getwd()), "/")[[1]]
country <- substr(dirname(getwd()), cty[nrow(cty), 1]+1, nchar(dirname(getwd())))

# Saving ------------------------------------------------------------------
write_xlsx(list("targets" = df), path = paste0("../data_", country, "_", date, ".xlsx"))
