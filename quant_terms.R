#===============================================================================
# PACKAGES 
#===============================================================================
pacman::p_load(tidyverse, openxlsx, tibble, spacyr, quanteda, readxl)

#===============================================================================
# DATA IMPORT 
#===============================================================================
cty <- "Uzbekistan" # <========================================================= change here!
date <- format(Sys.Date(), "%d%b%y")
date <- ifelse(substr(date, 1, 1) == "0", substr(date, 2, nchar(date)), date)
# ...

#setwd("../../../../")
setwd(paste0("data/countries/", str_replace(tolower(cty), "\\s", "_")))

filename <- list.files(pattern = "data.*\\.xlsx$")
dta <- read_excel(filename)

#===============================================================================
# DATA TWEAKS
#===============================================================================
# Little extras -----------------------------------------------------------
`%not_in%` <- negate(`%in%`)

# Identifiers -------------------------------------------------------------
dta <- dta %>% 
  mutate(doc_id = paste0("text", row_number()))

# Minor adjustment --------------------------------------------------------
dta <- dta %>% 
  mutate(`Target Text` = gsub("per cent", "percent", `Target Text`), 
         `Target Text` = gsub(" %", "%", `Target Text`)) # `NBT Text - English`

# Quantitative and time-bound terms, and numbers (en_core_web_...) -------------
# sm: small, for basic text (poor at similarity tasks)
# md: medium, uses pre-trained word embeddings, name entity recognition-NER (better semantic understanding)
# lg: large, uses pre-trained word embeddings, name entity recognition-NER (better semantic understanding) and word vectors
# trf: XL;, uses BERT and is highly accurate (state-of-the-art)
#spacyr::spacy_initialize(model = "en_core_web_sm") # es_core_news_sm, fr_core_news_sm
spacy_initialize(model = "en_core_web_sm") # es_core_news_sm, fr_core_news_sm
#spacy_initialize(python_executable = "/usr/local/bin/python3", model = "es_core_news_sm")
#spacy_initialize(python_executable = "/usr/local/bin/python3", model = "fr_core_news_sm")

#tmp <- spacy_parse(dta$`NBT Text - English`, entity = TRUE) %>% # additional_attributes = "like_num"
tmp <- spacy_parse(dta$`Target Text`, entity = TRUE) %>% # additional_attributes = "like_num"
  filter(lemma != "" & lemma != "•" & pos != "SPACE") %>% # always keep an eye out for more oddities
  group_by(doc_id) %>% mutate(token_id = row_number()) %>% ungroup() %>% # restarts the token position after removing white spaces
  mutate(id = row_number())
spacy_finalize()

# Adjustments -------------------------------------------------------------
wrd <- c("double", "halve", "half", "triple", "quadruple", "quarter", "quintuple")
lgs <- c("act", "acts", "bill", "bills", "regulation", "regulations", 
         "decree", "decrees", "article", "articles", "law", "laws", 
         "recommendation", "recommendations", "bill", "bills", "exco")
org <- c("target", "targets", "goal", "goals", "objective", "objectives", 
         "figure", "table", "zone", "zones", "strategy", "strategies", "strategic", 
         "plan", "plans", "nt", "phase", "phases", "agenda", "agendas", 
         "policy", "policies", "stage", "stages", "programme", "programmes", 
         "action", "actions", "budget")
mtr <- c("ha", "hectare", "hectares", "cm", "m", "km", "km2", "mile", 
         "miles", "g", "kg", "ton", "tons", "ºc", "oc", "microns", 
         "acre", "acres", "factor", "mw") # "m"?
mth <- c(">", "<", "=", "≥", "≤", "~", "≈")
qty <- c("thousand", "thousands", "hundred", "hundreds", "million", "millions", 
         "billion", "billions", "trillion", "trillions", 
         "mtco2e", "mtco₂e", "co2", "co2e", "co2eq", "co2-eq")
prc <- c("%", "percent", "percentage")
tme <- c("annually", "annum", "year", "years", "monthly", "month", "months", 
         "weekly", "week", "weeks", "daily", "day", "days", 
         "hourly", "hour", "hours", tolower(month.name), tolower(month.abb))
mny <- c("dollar", "usd", "euros", "eur", "$", "£", "¥", "€") # "M"?

tmp <- tmp %>% 
  mutate(lemma = tolower(lemma), # makes all tokens in "lemma" lowercase
         pos = ifelse(lemma %in% wrd, "NUM", pos), # ensures the words in "wrd" are treated as numbers
         entity = ifelse(lemma %in% lgs, "LAW", entity), # ensures that legal/legal-ish terms are treated as such
         entity = ifelse(lemma %in% org, "ORG", entity), # ensures that organizational terms are treated as such
         pos = ifelse(lemma %in% mtr, "NUM", pos), # ensures the measurements in "mtr" are treated as numbers
         entity = ifelse(lemma %in% mtr, lag(entity), entity), 
         pos = ifelse(lemma %in% qty, "NUM", pos), # ensures the measurements in "qty" are treated as numbers
         entity = ifelse(lemma %in% qty, "QUANTITY", entity), 
         pos = ifelse(lemma %in% prc, "NUM", pos), # ensures the measurements in "prc" are treated as numbers
         entity = ifelse(lemma %in% prc, "PERCENT", entity), 
         pos = ifelse(lemma %in% mth, "NUM", pos), # ensures mathematical symbols are treated as such
         entity = ifelse(lemma %in% mth, "CARDINAL", entity), 
         entity = ifelse(grepl("^[ivxlcdm]+$", token), "LAW", entity), # ensure roman numerals are understood as numbers (FYI: as.roman(15) = XV; as.numeric(as.roman("XV)) = 15)
         entity = ifelse(lemma %in% tme, "DATE", entity), # ensures that time-related names are treated as such
         entity = ifelse(lemma %in% mny, "MONEY", entity),  # ensures that money-related names are treated as such
         pos = ifelse(str_detect(lemma, "[0-9]+[-/–][0-9]+"), "NUM", pos), # "2021-2025", "138–153"
         entity = ifelse(str_detect(lemma, "[0-9]+[-/–][0-9]+"), lead(entity), entity), 
         entity = ifelse(pos == "NUM" & grepl("^[0-9]{4}$", lemma), "DATE", entity), # ensures 4-digit numbers with no commas are treated as a date
         pos = ifelse(str_detect(lemma, "^[~±][0-9]+([.,]?[0-9]+)?$"), "NUM", pos), # "~469.420"
         entity = ifelse(str_detect(lemma, "^[~±][0-9]+([.,]?[0-9]+)?$"), "CARDINAL", entity),
         )

tmp <- tmp %>% 
  mutate(entity = ifelse(grepl("^[A-Z]+$", token) & (token != "MW" & token != "BAU"), "ORG_B", entity), #"NBSAP"; "3,200 MW"; (might have to add more, keep an eye out!)
         entity = ifelse(grepl("^[A-Z][a-z]+$", token) & !grepl("^[.;]$", lag(token)) & 
                           !(token == "By" & token_id == 1), "ORG", entity), # Considers any token starting with a capital 1st letter as an "Organization", except if it is immediately preceded by "." or ";", or right at the beginning of the phrase in the case of "By"
         pos = ifelse(lemma == "least" & lead(pos) == "NUM", lead(pos), pos), # "{at} least 600" (ß) >>>
         entity = ifelse(lemma == "least" & lead(pos) == "NUM", lead(entity), entity), 
         pos = ifelse(lemma == "nautical" & lead(pos) == "NUM", lead(pos), pos), # "6 nautical miles"
         pos = ifelse(lemma == "close" & lead(lemma) == "to" & lead(pos, 2) == "NUM", "NUM", pos), # "close to zero" (∂) >>>
         pos = ifelse(lemma == "end" & lead(lemma) == "of" & lead(pos, 2) == "NUM", "NUM", pos), # "by the end of 2020" (∆) >>>
         entity = ifelse(pos == "NUM" & lead(lemma) == ")" & lag(lemma) == "(" & pos == "NUM", "CARDINAL_I", entity), # "two (2)" (ø) >>>
         entity = ifelse(lemma %in% mth, lead(entity), entity), 
         )

tmp <- tmp %>% 
  mutate(entity = ifelse(lemma == "by" & lead(pos) == "NUM", lead(entity), entity), # "by 2025"
         pos = ifelse(lemma == "by" & lead(pos) == "NUM", lead(pos), pos), 
         pos = ifelse(lemma == "of" & ((lag(pos) == "NUM" & lead(pos) == "NUM") | 
                                         lag(lemma) == "out" & lag(pos, 2) == "NUM" & lead(pos) == "NUM"), "NUM", pos), # "3 out of 5"..., "tons of CO2-eq" (∆) <<<
         entity = ifelse(lemma == "of" & ((lag(pos) == "NUM" & lead(pos) == "NUM") | 
                                            lag(lemma) == "out" & lag(pos, 2) == "NUM" & lead(pos) == "NUM"), lead(entity), entity), 
         pos = ifelse(lemma == "out" & lag(pos) == "NUM" & lead(lemma) == "of" & lead(pos, 2) == "NUM", "NUM", pos), # ... "3 out of 5"
         entity = ifelse(lemma == "out" & lag(pos) == "NUM" & lead(lemma) == "of" & lead(pos, 2) == "NUM", lead(entity), entity), 
         #entity = ifelse(lemma == "ton" & lag(pos) == "NUM" & lead(pos) == "NUM", "QUANTITY", entity), 
         pos = ifelse(lemma == "over" & lead(pos) == "NUM", lead(pos), pos), # "over 3,200"
         entity = ifelse(pos == "NUM" & lead(entity) == "CARDINAL", lead(entity), entity), # 450,000 hectares
         pos = ifelse(lemma == "in" & lead(pos) == "NUM" & lag(pos) == "NUM", lead(pos), pos), # "{three} years in six" (ƒ) >>>
         pos = ifelse(lemma == "at" & lead(pos) == "NUM", lead(pos), pos), # "at least 600" (∑) >>>
         pos = ifelse(lemma == "to" & lead(pos) == "NUM" & lag(pos) == "NUM", lead(pos), pos), # "2020 to 2025", "{from} 179 to 249" (∂) <<<
         pos = ifelse(lemma == "since" & lead(pos) == "NUM", lead(pos), pos), # "since 1992"
         pos = ifelse(lemma == "over" & lead(pos) == "NUM", lead(pos), pos), # "over 25,000"
         pos = ifelse(lemma == "at" & lead(lemma) == "least" & lead(pos, 2) == "NUM", lead(pos), pos), # "at least 600" (ß) <<<
         entity = ifelse(lemma == "at" & lead(lemma) == "least" & lead(pos, 2) == "NUM", lead(entity), entity), 
         pos = ifelse(lemma == "every" & lead(pos) == "NUM", lead(pos), pos), # "every three"
         pos = ifelse(lemma == "than" & (lag(lemma) == "less" | lag(lemma) == "more") & lead(pos) == "NUM", "NUM", pos), # "less than 25", "more than 50" (µ) >>>
         pos = ifelse(lemma == "/" & lead(pos) == "NUM" & lag(pos) == "NUM", lead(pos), pos), # "2020/21"
         pos = ifelse((lemma == "-" | lemma == "─") & lead(pos) == "NUM" & lag(pos) == "NUM", lead(pos), pos), # "300-thousand", "2021-2025" (π) >>>
         entity = ifelse(lemma == "(" & lead(entity) == "CARDINAL_I" & lead(lemma, 2) == ")" & lag(pos) == "NUM", "CARDINAL_I", entity), # "two (2)" (ø) <<<
         pos = ifelse(lemma == "(" & lead(entity) == "CARDINAL_I" & lead(lemma, 2) == ")" & lag(pos) == "NUM", "NUM", pos), 
         entity = ifelse(lemma == ")" & lag(entity) == "CARDINAL_I" & lag(lemma, 2) == "(" & lag(pos, 3) == "NUM", "CARDINAL_I", entity), # "two (2)" (ø) <<<
         pos = ifelse(lemma == ")" & lag(entity) == "CARDINAL_I" & lag(lemma, 2) == "(" & lag(pos, 3) == "NUM", "NUM", pos), 
         entity = ifelse(lemma == "/" & lag(pos) == "NUM", lag(entity), entity), # "15,000 ha/year"
         pos = ifelse(lag(lemma) == "/" & lag(pos) == "NUM", lag(pos), pos), 
         entity = ifelse(lag(lemma) == "/" & lag(pos) == "NUM", lag(entity), entity), 
         entity = ifelse(entity == "QUANTITY" & str_starts(lag(entity), "^MONEY"), lag(entity), entity), # US$ 3,097.28 million
         pos = ifelse(lemma == "per" & lead(lemma) == "year", lag(pos), pos), # "per year"
         entity = ifelse(lemma == "per" & lead(lemma) == "year", lag(entity), entity), 
         pos = ifelse(lemma == "year" & lag(lemma) == "per", lag(pos), pos), # "per year"
         entity = ifelse(lemma == "year" & lag(lemma) == "per", lag(entity), entity), 
         )

tmp <- tmp %>% 
  mutate(entity = ifelse(grepl("^\\d+[a-z]$", lemma), "KILL", entity), # "1a"
         entity = ifelse(grepl("^[a-z]\\d+$", lemma), "KILL", entity), # "T1", "G20"
         pos = ifelse(lemma == "baseline" & lag(pos) == "NUM", "NUM", pos), # "2020 baseline" ... "level", "levels"?
         entity = ifelse(lemma == "baseline" & lag(pos) == "NUM", "DATE", entity), 
         entity = ifelse(pos == "NUM" & lag(lemma) == "to" & str_starts(lag(entity, 2), "^ORG"), "KILL", entity), # "Map to 2030" (∂) <<<
         entity = ifelse(lemma == "from" & lead(pos) == "NUM" & lead(lemma, 2) == "to", "NUM", entity), # "from 179 to 249" (∂) <<<
         entity = ifelse((lemma == "-" | lemma == "─") & lag(pos) == "NUM" & lead(pos) == "NUM", lag(entity), entity), # "2021-2025" (π) <<<
         pos = ifelse((lemma == "-" | lemma == "─" | lemma == "to") & (lag(pos) == "NUM" | str_starts(lag(entity), "^PERCENT")) & 
                        (lead(pos) == "NUM" | str_starts(lead(entity), "^PERCENT")), "NUM", pos), # "10 to 12%", "178 to 205", "23.6% to 30%", "5-10", "2.35-5.89%", "400-800m" (π) (∂) <<<
         entity = ifelse(pos == "NUM" & ((lag(lemma) == "in" & lag(lemma, 2) == "publish") | 
                                        lag(lemma) == "publish"), "KILL", entity), # "published in 2023", "published 2023" (ƒ) <<<, 
         entity = ifelse(pos == "NUM" & lag(lemma) == "for", "KILL", entity), # "EU Biodiversity Strategy for 2030"
         entity = ifelse(pos == "NUM" & (lag(lemma) == "of" | lag(lemma) == ",") & (lag(entity, 2) == "ORG" | lag(entity, 2) == "LAW"), "KILL", entity), # "Act No. CII of 2013", "Bill of 2024", "policy of 2005", "Act, 2004" (∆) <<<
         entity = ifelse(pos == "NUM" & lag(lemma) == "[" & lead(lemma) == "]", "KILL", entity), # "[1]"
         entity = ifelse(lemma != "by" & pos == "NUM" & str_starts(lag(entity), "^ORG") & lag(token_id) != 1 & doc_id == lag(doc_id), "KILL", entity), # "Nature 2000", "strategy 2023-2030", "plan 2016-2025" (but not if preceding word is the 1st in the sentence, and has to be in the same target... and does not apply to "by")
         entity = ifelse(lemma != "by" & pos == "NUM" & str_starts(lead(entity), "^ORG") & doc_id == lead(doc_id), "KILL", entity), # "(2020 to) 2025 Nature for Climate Fund", "(2021-)2025 Strategy", "(2026)-2028 budget", "2022 European Innovative Teaching Awards", "One Health Approach" (has to be in the same target...and does not apply to "by")
         pos = ifelse((lemma == "less" | lemma == "more") & lead(pos) == "NUM" & lead(lemma) == "than", "NUM", pos), # "less than 25", "more than 50" (µ) <<<
         entity = ifelse((lemma == "less" | lemma == "more") & lead(pos) == "NUM" & lead(lemma) == "than", "CARDINAL_I", entity), # "less than 25", "more than 50" (µ) <<<
         entity = ifelse(lemma == "at" & lead(lemma) == "least" & lead(pos) == "NUM", lead(entity), entity), # "at least 600" (∑) <<<
         # "Plan for biodiversity (2011-2020)", "plan for action (2020-2026)"
         entity = ifelse(token == "N" & lead(token) == "/" & lead(token, 2) == "A", "KILL", entity), # "N/A"
         entity = ifelse(pos == "NUM" & (lead(lemma) == "th" | lead(lemma) == "st" | 
                                        lead(lemma) == "nd" | lead(lemma) == "rd"), "KILL", entity), # "9th"... st, nd, rd
         entity = ifelse(lemma == "zero" & lag(lemma) == "net", "KILL", entity), # "net zero"
         entity = ifelse(str_detect(lemma, ".pdf$"), "KILL", entity), # ".pdf"
         )

tmp <- tmp %>% 
  mutate(entity = ifelse((lemma == "-" | lemma == "─") & lag(entity) == "KILL", lag(entity), entity), 
         entity = ifelse(pos == "NUM" & (lag(lemma) == "-" | lag(lemma) == "─") & lag(entity) == "KILL", lag(entity), entity), 
         entity = ifelse(pos == "ADV" & lag(pos) == "NUM", lag(entity), entity), # "15,000 hectares annually"
         pos = ifelse(pos == "ADV" & lag(pos) == "NUM", lag(pos), pos), 
         )

tmp <- tmp %>% 
  mutate(doc_id = factor(doc_id, unique(doc_id)), 
         #entity = ifelse((grepl("_B$", entity) | grepl("_I$", entity)), substr(entity, 1, nchar(entity)-2), entity)) %>% 
         entity = ifelse(grepl("_[A-Z]$", entity), str_replace(entity, "_[A-Z]$", ""), entity)) %>% 
  filter(entity != "KILL" & (pos == "NUM" & !str_starts(entity, "^ORG") & !str_starts(entity, "^LAW")) | 
           str_starts(entity, "^MONEY") | str_starts(entity, "^PERCENT") | str_starts(entity, "^DATE")) %>% 
  mutate(seq_brk = c(0, diff(token_id) != 1)) %>% 
  mutate(seq_id = cumsum(seq_brk)) %>% 
  group_by(doc_id, sentence_id, seq_id, entity) %>% 
  summarise(conc_tokens = paste(token, collapse = " ")) %>% 
  ungroup()

tmp <- tmp %>% 
  mutate(conc_tokens = gsub("\\s%", "%", conc_tokens), 
         conc_tokens = gsub("\\s/\\s", "/", conc_tokens))

# Extras ------------------------------------------------------------------
counts <- tmp %>% 
  mutate(count = 1, 
         entity = ifelse(str_starts(entity, "^DATE"), "DATE", "QUANT")) %>% 
  select(c(doc_id, entity, count)) %>% 
  group_by(doc_id, entity) %>% 
  summarise(count = sum(count)) %>% 
  ungroup()

counts <- counts %>% 
  left_join(select(dta, doc_id, Target.Name, Document)) %>% 
  select(Target.Name, Document, entity, count) %>% 
  pivot_wider(names_from = entity, values_from = count) %>% 
  mutate(QUANT = ifelse(is.na(QUANT), 0, QUANT), 
         DATE = ifelse(is.na(DATE), 0, DATE))

countss <- counts %>% 
  mutate(QUANT = ifelse(QUANT == 0, 0, 1), 
         DATE = ifelse(DATE == 0, 0, 1)) %>% 
  left_join(select(dta, Target.Name, Source)) %>% 
  select(-Target.Name)

df_aux1 <- countss %>% 
  select(Document, Source) %>% 
  unique()
df_aux2 <- countss %>% 
  select(Document) %>% 
  mutate(count = 1) %>% 
  group_by(Document) %>% 
  summarise(ntargets = sum(count))

countss <- countss %>% 
  group_by(Document) %>% 
  summarise(QUANT = sum(QUANT), 
            DATE = sum(DATE)) %>% 
  left_join(df_aux2) %>% 
  mutate(`QUANT_%` = 100*(QUANT/ntargets), 
         `DATE_%` = 100*(DATE/ntargets))

extraroww <- as.data.frame(t(c("", "", sum(counts$DATE), sum(counts$QUANT))))
colnames(extraroww) <- colnames(counts)
counts <- rbind(counts, extraroww)

# Structure ---------------------------------------------------------------
tmp <- tmp %>% 
  select(-c(`seq_id`)) %>% 
  mutate(conc_tokens = paste0('"', conc_tokens, '"')) %>% 
  mutate(entity = ifelse(str_starts(entity, "^DATE"), "DATE", "QUANT")) %>% 
  group_by(doc_id, sentence_id, entity) %>% 
  summarise(summ = paste0(conc_tokens, collapse = ", "), .groups = 'drop') %>% 
  pivot_wider(values_from = summ, names_from = entity) %>% 
  mutate(QUANT = paste0(QUANT, " appear(s) in sentence ", sentence_id), 
         DATE = paste0(DATE, " appear(s) in sentence ", sentence_id)) %>% 
  ungroup() %>% 
  mutate(QUANT = ifelse(str_starts(QUANT, "^NA "), "", QUANT), 
         DATE = ifelse(str_starts(DATE, "^NA "), "", DATE))

tmp <- tmp %>% 
  select(-sentence_id) %>% 
  group_by(doc_id) %>% 
  summarise(QUANT = paste0(QUANT, collapse = "; "), 
            DATE = paste0(DATE, collapse = "; "), .groups = 'drop')

dta <- dta %>% 
  left_join(tmp) %>% 
  select(-c(doc_id)) %>% 
  mutate(QUANT = ifelse(is.na(QUANT), "", QUANT), 
         DATE = ifelse(is.na(DATE), "", DATE))

# Aesthetic tweaks --------------------------------------------------------
counts$DATE <- as.numeric(counts$DATE)
counts$QUANT <- as.numeric(counts$QUANT)

countss$DATE <- as.numeric(countss$DATE)
countss$QUANT <- as.numeric(countss$QUANT)
countss$ntargets <- as.numeric(countss$ntargets)
countss$`QUANT_%` <- round(as.numeric(countss$`QUANT_%`), 0)
countss$`DATE_%` <- round(as.numeric(countss$`DATE_%`), 0)

wb <- createWorkbook()
addWorksheet(wb, "Quantitative Terms", gridLines = FALSE)
writeData(wb, "Quantitative Terms", dta)
addWorksheet(wb, "Support1", gridLines = FALSE)
writeData(wb, "Support1", counts)
addWorksheet(wb, "Support2", gridLines = FALSE)
writeData(wb, "Support2", countss)

#===============================================================================
# SAVING
#===============================================================================
saveWorkbook(wb, paste0(cty, "_quantitative_Dominican_Republic_DraftORT.xlsx"), overwrite = TRUE)
