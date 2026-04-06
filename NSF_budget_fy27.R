---
  title: "NSF-budget-cuts-v25"
output: html_document
date: "2025-08-22"
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)
if (!require('rstudioapi')) BiocManager::install("rstudioapi");library(rstudioapi)

# change working directory to folder with script
setwd(dirname(rstudioapi::getSourceEditorContext()$path)) 

library(tidyverse)
library(readxl)
library(sf)
library(magrittr)

options(scipen=999)
```

```{r combine-files, eval=FALSE}
library(jsonlite)
library(purrr)
library(dplyr)
library(readr)

# get path for NSF grants
json_folder <- "NSF_Grants"
json_files <- list.files(json_folder, pattern = "\\.json$", full.names = TRUE)

extract_fields <- function(grant) {
  data.frame(fund_oblg_fiscal_yr = grant$oblg_fy$fund_oblg_fiscal_yr,
             fund_oblg_amt = grant$oblg_fy$fund_oblg_amt) %>%
    mutate(awd_id = grant$awd_id %||% NA,
           agcy_id = grant$agcy_id %||% NA,
           tran_type = grant$tran_type %||% NA,
           awd_inst_txt = grant$awd_istr_txt %||% NA,
           cfda_num = grant$cfda_num %||% NA,
           awd_eff_date = grant$awd_eff_date %||% NA,
           awd_exp_date = grant$awd_exp_date %||% NA,
           tot_intn_awd_amt = grant$tot_intn_awd_amt %||% NA,
           awd_amount = grant$awd_amount %||% NA,
           awd_min_amd_letter_date = grant$awd_min_amd_letter_date %||% NA,
           awd_max_amd_letter_date = grant$awd_max_amd_letter_date %||% NA,
           dir_abbr = grant$dir_abbr %||% NA,
           div_abbr = grant$div_abbr %||% NA,
           inst_name = grant$inst$inst_name %||% NA,
           inst_street_address = grant$inst$inst_street_address %||% NA,
           inst_city_name = grant$inst$inst_city_name %||% NA,
           inst_state_name = grant$inst$inst_state_name %||% NA,
           inst_zip  = grant$inst$inst_zip_code %||% NA,
           awd_instr = grant$awd_istr_txt %||% NA)
}


# Apply extraction to each record
all_data <- map_dfr(json_files, function(file) {
  fromJSON(file) %>% extract_fields()
})

library(data.table)

fwrite(all_data, "nsf_grants.csv")
```


```{r clean-grants}
nsf_grants <- read.csv("nsf_data/nsf_grants.csv")

#directorates to include
dir_incl <- c("BIO", "CSE", "EDU", "ENG", "GEO", "MPS", "SBE", "TIP")

# divisions within office of director to include
div_incl <- c("OIA", "OISE")

# helper column to put listed account categories together (O/D divisions are split out)
nsf_grants %<>% mutate(account_name = ifelse(dir_abbr == "O/D", div_abbr, dir_abbr)) %>%
  filter(account_name %in% c(dir_incl, div_incl))
```


```{r budget-cuts}
# https://www.usinflationcalculator.com/ inflation adjusted to 2024 using: https://www.usinflationcalculator.com/ (note FY2025 is excluded)
inf_adj <- c(1.21, 1.16, 1.07, 1.03, 1, .98)

# df of historic funding in FY2020-2024, proposed for FY2026
# unit is dollars in millions
budg_tab <- read.csv("nsf_data/budg_table.csv")

budg_tab %<>% filter(!is.na(X)) %>%
  mutate(across(X2020_budg:X2026_budg, ~.x * inf_adj)) %>%
  rowwise() %>%
  mutate(past_mean = mean(c_across(X2020_budg:X2024_budg), na.rm = TRUE)) %>%
  ungroup() %>%
  rowwise() %>%
  mutate(prop_cut = 1 - X2026_budg/past_mean) %>%
  ungroup() %>%
  rename(account_name = X) %>%
  select(prop_cut, account_name)

inf_by_year <- tibble(inf = inf_adj, fund_oblg_fiscal_yr = c(2020:2024, 2026))

# calculate losses for each grant
nsf_grants %<>% 
  left_join(inf_by_year) %>%
  filter(!is.na(inf)) %>%
  mutate(adj_fund = inf_adj * fund_oblg_amt) %>%
  left_join(budg_tab) 

nsf_grants <- bind_rows(nsf_grants %>% mutate(cut_amt = prop_cut * adj_fund), 
                        nsf_grants %>% mutate(account_name = "House_Tot", cut_amt = .23 * adj_fund)) 


```


```{r Get FIPS Codes}

geo_dict <- read.csv("nsf_data/NSF_addresses_US_tract_county_cong119.csv") %>%
  distinct() %>%
  mutate(FIPS = str_pad(CountyFIPS_str, 5, pad = "0"),
         GEOID = str_pad(CongFIPS, 4, pad="0")) %>%
  filter(! StateName %in% c("American Samoa", "Guam", "Commonwealth of the Northern Mariana Islands", "Puerto Rico")) %>%
  select(FIPS, GEOID, inst_name, StateName, CountyName)

nsf_grants %<>% left_join(geo_dict)
```

```{r Commuter Weighting}
# commute is a dataframe derived from 2022 Census data with the following columns
# ORIGIN: is the FIPS code for the county of residence
# DESTINATION: is the FIPS code for the county of work
# COMMUTES: is the number of workers commuting from the specific ORIGIN to DESTINATION

# IMPORTANT: some FIPS codes have leading zeros
commute_raw <- read.csv("./data/OD_countySum001_2016.csv") %>%
  mutate(ORIGIN = str_pad(ORIGIN, 5, pad = "0"),
         DESTINATION = str_pad(DESTINATION, 5, pad = "0"))

# calculate proportion weights
commute <- commute_raw %>% 
  # calculate the total number of workers who work in a given county
  group_by(DESTINATION) %>%
  summarize(DESTINATION_total_workers = sum(COMMUTES)) %>%
  # join this back to the full commuter dataframe
  left_join(commute_raw) %>%
  # for each ORIGIN - DESTINATION pair, calculate proportion as the number
  # of workers from ORIGIN who work in DESTINATION divided by the total 
  # number of people who work in DESTINATION
  mutate(proportion = COMMUTES/DESTINATION_total_workers)

# Quality check: all destination weights should sum to 1
commute %>% 
  group_by(DESTINATION) %>% 
  summarize(sum = round(sum(proportion), digits=5)) %>% 
  filter(sum < 1) %>%
  nrow() 

```

```{r County Calculations}

#summarize NIH data by FIPS code
NSF_budget_cuts_FIPS <- expand.grid(FIPS = unique(nsf_grants$FIPS),
                                    account_name = unique(nsf_grants$account_name),
                                    fund_oblg_fiscal_yr = unique(nsf_grants$fund_oblg_fiscal_yr)) %>%
  left_join(nsf_grants) %>%
  group_by(FIPS, account_name, fund_oblg_fiscal_yr) %>% 
  summarise(budg_loss = sum(cut_amt, na.rm=TRUE)) %>%
  group_by(FIPS, account_name) %>%
  summarise(budg_loss = mean(budg_loss, na.rm=TRUE)) 


#combine commuter data with NIH data
county_commute_NSF <- merge(commute, NSF_budget_cuts_FIPS, by.x = "DESTINATION", by.y = "FIPS", all.x = TRUE) %>%
  filter(!is.na(account_name)) %>%
  mutate_all(funs(replace(., is.na(.), 0))) %>%
  mutate(budg_loss = budg_loss * proportion) %>%
  rename(FIPS = ORIGIN) %>%
  group_by(FIPS, account_name) %>%
  summarize(budg_loss = sum(budg_loss, na.rm=TRUE)) %>%
  ungroup() %>%
  pivot_wider(names_from = account_name, 
              names_glue = "{account_name}_budg",
              values_from = budg_loss) %>%
  rename(sum_house = House_Tot_budg) %>%
  rowwise() %>%
  mutate(sum_budg = sum(c_across(ends_with("budg")), na.rm = TRUE)) %>%
  ungroup() %>%
  mutate_all(funs(replace(., is.na(.), 0))) 

# read in state FIPS to name dictionary
state_dict <- read.csv("data/state_and_county_fips_master.csv") %>%
  mutate(state_FIPS = str_pad(fips, 5, pad = "0")) %>%
  filter(endsWith(state_FIPS, "000")) %>%
  mutate(state_FIPS = substr(state_FIPS, 1, 2)) %>%
  mutate(state = str_to_title(tolower(name))) %>%
  select(-c(name, fips))

# manually fix issue with capitalization of "of" 
state_dict$state <- ifelse(state_dict$state == "District Of Columbia", "District of Columbia" , state_dict$state)

#add state name
county_commute_NSF <- read.csv("data/county_pop.csv") %>%
  mutate(FIPS = str_pad(FIPS, 5, pad = "0")) %>%
  select(FIPS, state, county) %>%
  right_join(county_commute_NSF) 

county_commute_NSF <- read.csv("data/state_abbrev.csv") %>%
  rename(state_code = Abbreviation,
         state = State) %>%
  left_join(state_dict) %>%
  right_join(county_commute_NSF) %>%
  select(-state_FIPS)

#add state name
county_commute_NSF <- read.csv("data/state_abbrev.csv") %>%
  rename(state_code = Abbreviation,
         StateName = State) %>%
  right_join(county_commute_NSF) %>%
  relocate(sum_house, .after = last_col()) %>%
  mutate(sum_budg_econ = sum_budg *2.25)

print(nrow(county_commute_NSF))
sum(is.na(county_commute_NSF$state_code))
sum(county_commute_NSF$sum_budg, na.rm=TRUE)

write.csv(county_commute_NSF, "nsf_output/NSF_budget_county.csv", row.names=FALSE)

```

# Congressional Districts

```{r Prep District Commuter Flows}
cong_commute <- read.csv("./data/JT_congress_July30.csv") %>%
  mutate(Cong_ORIGIN = str_pad(Cong_ORIGIN, 4, pad = "0"),
         Cong_DESTINATION = str_pad(Cong_DESTINATION, 4, pad = "0"))

cong_info <- read.csv("./data/us_representatives_119th_congress.csv") %>%
  mutate(GEOID = str_pad(GEOID, 4, pad = "0")) %>%
  select(GEOID, STATE_NAME, NAME, PARTY) %>%
  rename(state = STATE_NAME,
         pol_party = PARTY,
         rep_name = NAME)

#get total workers per cong district
cong_commute_sum <- cong_commute %>%
  group_by(Cong_DESTINATION) %>%
  summarise(total_workers = sum(COMMUTES))

#merge in total workers
cong_commute <- left_join(cong_commute, cong_commute_sum)

#calculate proportion of workers who work in district X who live in district Y
cong_commute$proportion <- cong_commute$COMMUTES / cong_commute$total_workers

```


```{r Merge Cong Data}
#summarize NIH data by cong district code
NSF_budget_cuts_GEOID <- expand.grid(GEOID = unique(nsf_grants$GEOID),
                                     account_name = unique(nsf_grants$account_name),
                                     fund_oblg_fiscal_yr = unique(nsf_grants$fund_oblg_fiscal_yr)) %>%
  left_join(nsf_grants) %>%
  group_by(GEOID, account_name, fund_oblg_fiscal_yr) %>% 
  summarise(budg_loss = sum(cut_amt, na.rm=TRUE)) %>%
  group_by(GEOID, account_name) %>%
  summarise(budg_loss = mean(budg_loss, na.rm=TRUE)) 

#combine commuter data with NIH data
cong_commute_NSF <- merge(cong_commute, NSF_budget_cuts_GEOID, by.x = "Cong_DESTINATION", by.y = "GEOID", all = TRUE) %>%
  filter(!is.na(account_name)) %>%
  mutate_all(funs(replace(., is.na(.), 0))) %>%
  mutate(budg_loss = budg_loss * proportion) %>%
  rename(GEOID = Cong_ORIGIN) %>%
  group_by(GEOID, account_name) %>%
  summarize(budg_loss = sum(budg_loss, na.rm=TRUE)) %>%
  ungroup() %>%
  pivot_wider(names_from = account_name, 
              names_glue = "{account_name}_budg",
              values_from = budg_loss) %>%
  rename(sum_house = House_Tot_budg) %>%
  rowwise() %>%
  mutate(sum_budg = sum(c_across(ends_with("budg")), na.rm = TRUE)) %>%
  ungroup() %>%
  mutate_all(funs(replace(., is.na(.), 0))) %>%
  mutate(state_FIPS =  substr(GEOID, 1, 2))

#add in rep names
cong_commute_NSF <- left_join(cong_commute_NSF, cong_info)

#add state name
cong_commute_NSF <- read.csv("data/state_abbrev.csv") %>%
  rename(state_code = Abbreviation,
         state = State) %>%
  right_join(cong_commute_NSF) %>%
  select(-state_FIPS) %>%
  filter(!is.na(state_code)) %>%
  relocate(sum_house, .after = last_col()) %>%
  mutate(sum_budg_econ = sum_budg *2.25)

print(nrow(cong_commute_NSF))
sum(cong_commute_NSF$sum_budg, na.rm=TRUE)

write.csv(cong_commute_NSF, "nsf_output/NSF_budget_cong.csv", row.names=F)

```
```{r state summaries}
cong_commute_NSF %>%
  group_by(state, state_code) %>%
  summarise(across(ends_with(c("budg", "house", "econ")), ~ sum(.x, na.rm = TRUE))) %>%
  filter(!is.na(state_code))  -> state_cong

print(nrow(state_cong))

write.csv(state_cong, file="nsf_output/NSF_budget_state.csv", row.names=FALSE)

```

```{r Get Stats Used in Report}
NSF_budg_state <- read.csv("nsf_output/NSF_budget_state.csv")

filter(NSF_budg_state, sum_budg*2.25 > 500000000) %>%
  select(state, sum_budg) %>%
  arrange(desc(sum_budg))

NSF_budg_cong <- read.csv("nsf_output/NSF_budget_cong.csv")

mutate(NSF_budg_cong, sum_budg = sum_budg*2.25) %>%
  filter(sum_budg > 10000000)

```


```{r topline state stats}
nsf_grants %>%
  group_by(inst_state_name, inst_name, fund_oblg_fiscal_yr) %>%
  summarize(annual_cut = sum(cut_amt)) %>%
  group_by(inst_state_name, inst_name) %>%
  summarize(annual_loss = mean(annual_cut)) %>%
  group_by(inst_state_name) %>%
  slice_max(annual_loss, n=2) %>%
  mutate(econ_loss = annual_loss*2.25) %>%
  mutate(annual_loss = round(annual_loss/1000000, digits=1),
         econ_loss = round(econ_loss/1000000, digits=1)) %>%
  filter(inst_state_name %in% state.name) %>%
  rename(State = inst_state_name,
         `Research Org` = inst_name,
         `Projected White House Budget Reduction ($M)` = annual_loss,
         `Projected Economic Loss ($M)` = econ_loss) %>%
  write.csv("nsf_output/top2inst_state.csv", row.names=FALSE)  

nsf_grants %>%
  group_by(inst_state_name, fund_oblg_fiscal_yr) %>%
  summarize(annual_cut = sum(cut_amt)) %>%
  group_by(inst_state_name) %>%
  summarize(annual_loss = mean(annual_cut)) %>%
  filter(inst_state_name %in% state.name) %>%
  mutate(econ_loss = annual_loss*2.25) %>%
  mutate(annual_loss = round(annual_loss/1000000, digits=1),
         econ_loss = round(econ_loss/1000000, digits=1)) %>%
  rename(State = inst_state_name,
         `Projected White House Budget Reduction ($M)` = annual_loss,
         `Projected Economic Loss ($M)` = econ_loss) %>%
  write.csv("nsf_output/static_state_loss.csv", row.names=FALSE)  
```