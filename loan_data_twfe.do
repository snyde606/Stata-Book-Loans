use "loans_merged.dta", clear

* Dummy variable for counting; each row is 1 loan
gen one_loan = 1

* Save unique mapping from bib_doc_id to other columns, for re-merging later
preserve
duplicates drop bib_doc_id, force
keep bib_doc_id year_scanned location _oclc
save "id_to_other_cols.dta", replace
restore

* Count loans per (bib_doc_id, year_loaned) pair
collapse (sum) number_of_loans = one_loan, by(bib_doc_id year_loaned)
save "loan_counts.dta", replace

* Get unique ids and years, to perform outer product to generate a balanced sample
use "loans_merged.dta", clear
duplicates drop bib_doc_id, force
keep bib_doc_id
tempfile ids
save `ids'

use "loans_merged.dta", clear
duplicates drop year_loaned, force
keep year_loaned
tempfile years
save `years'

* Outer product via {cross}
use `ids', clear
cross using `years'
sort bib_doc_id year_loaned
tempfile all_combos
save `all_combos'

* Merge number_of_loans into year_loaned<>bib_doc_id cross, fill missing with 0
use `all_combos', clear
merge 1:1 bib_doc_id year_loaned using "loan_counts.dta", nogenerate
replace number_of_loans = 0 if missing(number_of_loans)

* Merge in year_scanned, location, _oclc
merge m:1 bib_doc_id using "id_to_other_cols.dta", nogenerate

* Create was_loaned binary indicator
gen was_loaned = number_of_loans > 0

* Create year_location string for fixed effects
tostring year_loaned, gen(year_str)
gen year_location = year_str + "_" + location
drop year_str

* Create log_loans = ln(number_of_loans + 1)
gen log_loans = ln(number_of_loans + 1)

sort number_of_loans

* Replace missing year_scanned values with 999999
replace year_scanned = 999999 if missing(year_scanned)

* Create treatment binary variable: is_post_scan = 1 if year_loaned > year_scanned, else 0
gen is_post_scan = year_loaned > year_scanned

// Run TWFE with Book FE (bib_doc_id) and Year-Location FE (year_location)
areg log_loans is_post_scan, absorb(bib_doc_id year_location)

local coef = _b[is_post_scan]
local se = _se[is_post_scan]
local sample_size = e(N)
di "log-OLS Coefficient: " `coef'
di "Standard Error: " `se'
di "Sample Size: " `sample_size'

