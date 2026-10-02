# =============================================================================
# tidycreel: a one-hour guided tour
# -----------------------------------------------------------------------------
# Audience : fisheries students / biologists who know some R and some creel
#            survey vocabulary, but have never used tidycreel.
# Format   : run top to bottom. Every section is a numbered ACT with a time
#            budget. Sections are RStudio-foldable (Alt/Cmd + Shift + O) and
#            knitr-spinnable (`knitr::spin("tidycreel_walkthrough.R")`).
# Big idea : a creel survey is a *sampling design* first and a dataset second.
#            tidycreel keeps the design attached to the data so every estimate
#            carries its own variance, and so mistakes get caught early.
#
# TIME MAP (60 min)
#   ACT 0  Install and set up ................................  5 min
#   ACT 1  The mental model and the vocabulary ................  3 min
#   ACT 2  Design BEFORE you sample: power and sample size ....  8 min
#   ACT 3  Building the field schedule .......................  8 min
#   ACT 4  Data hygiene before estimation ....................   5 min
#   ACT 5  The three-line core workflow (effort) .............   8 min
#   ACT 6  Interviews: CPUE, harvest, total catch ............   8 min
#   ACT 7  Biological data: species, lengths, ages ...........   5 min
#   ACT 8  Descriptive summaries (no expansion) ..............   3 min
#   ACT 9  Other survey types (camera, hybrid, bus route) ....   3 min
#   ACT 10 Diagnostics, plots, and export ....................   3 min
#   ACT 11 Simulation: close the loop ........................   1 min
# =============================================================================

# =============================================================================
# ACT 0 — INSTALLATION AND SETUP                                        (5 min)
# =============================================================================
# tidycreel is not on CRAN. It installs from GitHub. Run ONE of the following
# (pak is faster and resolves system deps better; devtools is the classic).
#
# Requirements: R >= 4.1.0 (the |> native pipe is used throughout).

if (FALSE) {
  # <- set to TRUE the first time you run this on a new machine

  install.packages("pak")
  pak::pak("chrischizinski/tidycreel")

  # or:
  # install.packages("devtools")
  # devtools::install_github("chrischizinski/tidycreel")

  # Optional but used in this walkthrough for plots and export:
  install.packages(c("ggplot2", "survey"))
  install.packages('tidyverse')

  # Optional extras that unlock Suggests-gated features:
  #   writexl / readxl  -> write_schedule()/read_schedule() to .xlsx
  #   glmmTMB, lme4     -> estimate_effort_aerial_glmm()
  #   duckdb, DBI       -> database-backed ingestion (tidycreel.connect)
  # install.packages(c("writexl", "readxl", "glmmTMB", "duckdb", "DBI"))

  # Installing from a LOCAL clone instead (what you do when developing):
  # devtools::install("~/path/to/tidycreel")     # or pak::local_install(".")
}

library(tidycreel)
library(ggplot2)

# Always state the version in teaching material — the API is still moving.
packageVersion("tidycreel")

# Reproducibility: every resampling / scheduling step in tidycreel takes a seed.
set.seed(2026)


# =============================================================================
# ACT 1 — THE MENTAL MODEL                                              (3 min)
# =============================================================================
# tidycreel has exactly one object that matters: the `creel_design`.
#
#   creel_design(calendar)      <- WHAT the sampling universe is (days, strata)
#     |> add_counts(...)        <- effort observations
#     |> add_interviews(...)    <- angler party records (catch, hours, party)
#     |> add_catch(...)         <- species-level catch, long format
#     |> add_lengths(...)       <- fish lengths
#     |> add_ages(...)          <- fish ages
#     |> estimate_*()           <- design-based estimates + variance
#
# Everything downstream inherits the strata, weights, and finite-population
# corrections from the design. That is the entire point: you never hand-build a
# weight, and you cannot silently estimate a total from an unweighted mean.
#
# Under the hood it is the `survey` package. tidycreel is the creel dialect on
# top of it — you speak "days, strata, counts, effort", not "psu, fpc, ~strata".

# The package ships controlled VALUE vocabularies for the three columns whose
# coding actually changes the maths. Anything outside these values is rejected
# rather than quietly recoded.
creel_vocabulary()

# One column at a time:
creel_vocabulary("trip_status") # complete / incomplete  -> which CPUE estimator
creel_vocabulary("catch_type") # caught / harvested / released
creel_vocabulary("length_type") # harvest / release

# `creel_schema()` is a formal column map: it tells tidycreel how YOUR agency's
# column names correspond to the vocabulary, so you can keep your raw headers.
schema <- creel_schema(
  survey_type = "instantaneous",
  date_col = "survey_date",
  strata_cols = "daytype",
  count_col = "anglers_seen",
  catch_col = "n_fish",
  effort_col = "hrs",
  trip_status_col = "status",
  catch_uid_col = "catch_row_id",
  interview_uid_col = "intvw_id",
  species_col = "spp",
  catch_count_col = "n_by_spp",
  catch_type_col = "fate",
  length_uid_col = "len_row_id",
  length_mm_col = "tl_mm",
  length_count_col = "n_at_len",
  length_type_col = "len_type"
)
print(schema)

# validate_creel_schema() fails LOUDLY and names every missing role. Try
# deleting `count_col` above and re-running to see the failure mode — this is
# the check that stops a mismapped column from silently becoming an estimate.
validate_creel_schema(schema)


# =============================================================================
# ACT 2 — DESIGN BEFORE YOU SAMPLE                                      (8 min)
# =============================================================================
# The most valuable part of the package happens before any fish is measured.
# Question: how many days must we sample to hit a target precision?

# ---- 2a. Effort sample size from pilot data --------------------------------
# Neyman-style stratified allocation. Inputs are per stratum:
#   N_h    = total days available in the stratum across the season
#   ybar_h = pilot mean daily effort (angler-hours)
#   s2_h   = pilot VARIANCE (not sd) of daily effort
creel_n_effort(
  cv_target = 0.15,
  N_h = c(weekday = 132, weekend = 52),
  ybar_h = c(weekday = 280, weekend = 550),
  s2_h = c(weekday = 14400, weekend = 32400)
)
# Read the output as a plan: n per stratum, and the CV you should expect.
# Note the allocation is NOT proportional to N_h — weekends are more variable,
# so they earn more days per unit of calendar.

# `optimal_n()` is the same machinery with an explicit cost ratio, for when a
# weekend day costs more to staff than a weekday.
optimal_n(
  cv_target = 0.15,
  N_h = c(weekday = 132, weekend = 52),
  ybar_h = c(weekday = 280, weekend = 550),
  s2_h = c(weekday = 14400, weekend = 32400),
  cost_ratio = 1.5
)

# The inverse question — "we can only afford n days, what precision do we get?"
cv_from_n(
  type = "effort",
  n = 60,
  N_h = c(weekday = 132, weekend = 52),
  ybar_h = c(weekday = 280, weekend = 550),
  s2_h = c(weekday = 14400, weekend = 32400)
)

# ---- 2b. power_creel(): three planning modes -------------------------------
# mode = "effort_n": days needed for a target RSE on total effort
power_creel(
  mode = "effort_n",
  target_rse = 0.20,
  strata = c("weekday", "weekend"),
  N_h = c(90, 30),
  ybar_h = c(42, 68),
  s2_h = c(196, 441)
)

# mode = "cpue_n": interviews needed for a target RSE on a RATIO estimate.
# CPUE is a ratio, so its precision depends on the CVs of BOTH numerator and
# denominator and on their correlation (rho). This is the classic reason a
# survey that nails effort still reports a useless catch rate.
power_creel(
  mode = "cpue_n",
  target_rse = 0.15,
  cv_catch = 0.85,
  cv_effort = 0.55,
  rho = 0.35
)

# mode = "power": can this survey detect a 20% change against historical CV?
power_creel(
  mode = "power",
  n = 120L,
  cv_historical = 0.42,
  delta_pct = 0.20
)

# ---- 2c. Audit a proposed design -------------------------------------------
# You have a proposed allocation (often "what we did last year"). Does it meet
# the target? validate_design() answers per stratum, not just in aggregate.
report <- validate_design(
  N_h = c(weekday = 132, weekend = 52),
  ybar_h = c(weekday = 280, weekend = 550),
  s2_h = c(weekday = 14400, weekend = 32400),
  n_proposed = c(weekday = 40L, weekend = 26L),
  cv_target = 0.15
)
print(report)
report$results # tidy data frame, drop straight into a report table

# TEACHING POINT: stop here and ask the room what happens to the required n
# when cv_target moves 0.15 -> 0.10. (Answer: it roughly doubles; precision is
# bought with the SQUARE of the effort. Most creel budgets die here.)

# =============================================================================
# ACT 3 — BUILDING THE FIELD SCHEDULE                                   (8 min)
# =============================================================================
# A creel schedule is a probability sample of days x periods. If a crew picks
# "a nice Saturday", the design is broken and no estimator can rescue it.

# ---- 3a. Which DAYS get sampled --------------------------------------------
sched <- generate_schedule(
  start_date = "2026-05-01",
  end_date = "2026-09-30",
  n_periods = 2, # AM / PM shifts
  period_labels = c("Morning", "Afternoon"),
  sampling_rate = c(weekday = 0.30, weekend = 0.50), # oversample weekends
  seed = 42 # reproducible draw
)
head(sched, 8)
table(sched$day_type)

# include_all = TRUE returns EVERY calendar day with a `sampled` flag. This is
# what you want as the analysis calendar: the unsampled days are the population
# you are expanding to, and dropping them biases the expansion.
sched_full <- generate_schedule(
  start_date = "2026-05-01",
  end_date = "2026-09-30",
  n_periods = 1,
  sampling_rate = c(weekday = 0.30, weekend = 0.50),
  include_all = TRUE,
  seed = 42
)
table(sched_full$day_type, sched_full$sampled)

# Special periods (openers, tournaments, holidays) become their own stratum,
# because their effort distribution is nothing like an ordinary weekend.
opener <- data.frame(
  start_date = as.Date("2026-05-30"),
  end_date = as.Date("2026-05-31"),
  label = "high_use",
  reason = "opener"
)
# NOTE: this small toy window triggers a "fragile schedule design" warning —
# carving 2 opener days out of a 6-day window leaves the weekend stratum with
# nothing. That warning is the package doing its job; on a real season it fires
# only when a special period really has starved a stratum.
sched_hu <- generate_schedule(
  start_date = "2026-05-28",
  end_date = "2026-06-02",
  n_periods = 1,
  sampling_rate = c(weekday = 1, weekend = 1, high_use = 1),
  include_all = TRUE,
  expand_periods = FALSE,
  seed = 42,
  special_periods = opener
)
sched_hu[, c(
  "date",
  "day_type",
  "final_stratum",
  "special_period_reason",
  "sampled"
)]

# The schedule carries an audit trail as attributes — show this to a reviewer
# who asks "how were opener days allocated?"
attr(sched_hu, "special_period_audit")
attr(sched_hu, "special_period_allocation")

# ---- 3b. Which TIMES within a day ------------------------------------------
# Three strategies, same output shape. Choose by what the crew can actually do.
ct_random <- generate_count_times(
  start_time = "06:00",
  end_time = "14:00",
  strategy = "random",
  n_windows = 4,
  window_size = 30,
  min_gap = 10,
  seed = 42
)
ct_random

ct_systematic <- generate_count_times(
  start_time = "06:00",
  end_time = "14:00",
  strategy = "systematic",
  n_windows = 4,
  window_size = 30,
  min_gap = 10,
  seed = 42
)
ct_systematic

# "fixed" is for crews that must count at set clock times (bridges, ramps).
generate_count_times(
  strategy = "fixed",
  fixed_windows = data.frame(
    start_time = c("07:00", "09:30", "12:00"),
    end_time = c("07:30", "10:00", "12:30")
  )
)

# Progressive (roving) counts: the count is a moving circuit, so what you
# randomise is the START offset within the circuit time tau.
generate_progressive_start(
  open_start = "06:00",
  open_end = "16:00", # T = 10 h open period
  circuit_time = 2, # tau = 2 h  -> 5 discrete start offsets
  strategy = "discrete",
  n = 10,
  seed = 99
)

# ---- 3c. Hand the crew one sheet -------------------------------------------
sched_week <- generate_schedule(
  start_date = "2026-06-01",
  end_date = "2026-06-07",
  n_periods = 2,
  sampling_rate = c(weekday = 0.5, weekend = 0.8),
  seed = 42
)
field_schedule <- attach_count_times(sched_week, ct_systematic)
head(field_schedule, 10)

# Visual check — a schedule plot catches clustering that a table hides.
autoplot(sched_week, title = "Field schedule, first week of June 2026")

# Verified round trip (writes to a temp dir so this walkthrough leaves no mess):
tmp_csv <- file.path(tempdir(), "count_schedule_2026.csv")
write_schedule(field_schedule, tmp_csv)
write_schedule(field_schedule, file.path(tempdir(), "count_schedule_2026.xlsx")) # needs writexl
sched_reload <- read_schedule(tmp_csv)
str(as.data.frame(sched_reload)[1, ])
# Dates, strata, and period_id survive the round trip. `window_id` comes back as
# character, not integer — CSV has no type system, and read_schedule() only
# restores the types it can infer. Check classes after any reload before you
# join on a column.

# =============================================================================
# ACT 4 — DATA HYGIENE BEFORE ESTIMATION                                (5 min)
# =============================================================================
# The example datasets. Loading them by name keeps the walkthrough runnable
# without agency data.
data(example_calendar) # one row per season day: date, day_type
data(example_counts) # instantaneous counts / effort_hours per day
data(example_interviews) # one row per intercepted party
data(example_catch) # long species-level catch
data(example_lengths) # fish lengths (individual + binned)
data(example_ages) # aged fish

str(example_calendar)
head(example_counts)
head(example_interviews)

# ---- 4a. Structural validation ---------------------------------------------
# Checks types, missingness, impossible values, out-of-range dates.
vres <- validate_creel_data(example_counts, example_interviews)
print(vres)

# Deliberately broken data, so students see what a failure looks like:
bad_counts <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02")),
  day_type = c("weekday", "weekend"),
  count = c(10L, NA_integer_)
)
bad_interviews <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02")),
  fish_kept = c(2L, -1L), # negative harvest
  species = c("walleye", "") # empty species
)
print(validate_creel_data(bad_counts, bad_interviews))

# ---- 4b. Outliers ----------------------------------------------------------
# Flags, does not delete. The 14-hour "trip" is usually a data-entry error, but
# that is a biologist's call, not a function's.
flag_outliers(
  data.frame(
    interview_id = 1:8,
    effort = c(1.0, 1.5, 2.0, 1.8, 1.2, 1.9, 2.1, 15.0)
  ),
  col = effort
)

# ---- 4c. Species names -----------------------------------------------------
# Free-text species fields are where multi-year datasets go to die.
standardize_species(
  data.frame(species = c("walleye", "Largemouth Bass", "UNKNOWN", "Wiper")),
  custom_codes = c("Wiper" = "WPR") # AFS codes plus your local overrides
)


# =============================================================================
# ACT 5 — THE THREE-LINE CORE WORKFLOW: EFFORT                          (8 min)
# =============================================================================
# 1. define the universe   2. attach observations   3. estimate

design <- creel_design(example_calendar, date = date, strata = day_type)
print(design) # 14 days, weekday/weekend strata, nothing attached yet

design <- add_counts(design, example_counts)
print(design) # counts attached; the internal survey object is now built

effort <- estimate_effort(design)
print(effort) # total, SE, 95% CI

# UNITS WARNING — the single most common tidycreel mistake:
# estimate_effort() expands whatever column you give it, without converting
# units. example_counts$effort_hours is ALREADY angler-hours (count x open
# hours), so the answer is angler-hours. Hand it a raw instantaneous count and
# you get angler-DAYS, not angler-hours.
# You will have seen tidycreel say exactly that in a warning above:
#   "Instantaneous counts were expanded without a period length."
# The fix when your column is a raw count is to supply the period each count
# was randomised within:
#   add_counts(design, counts, period_length_col = open_hours)

# ---- 5a. Grouped estimates -------------------------------------------------
# `by` takes tidyselect, so bare names, several columns, or starts_with().
estimate_effort(design, by = day_type)
# Interpretation drill: the two stratum totals look similar, but there are 10
# weekdays and 4 weekend days. Per DAY the weekend is ~3x the weekday. Always
# divide by N_h before telling a manager where the pressure is.

# ---- 5b. Variance methods --------------------------------------------------
# taylor (default) : linearisation, fast, right for smooth statistics
# bootstrap        : resampling, use for non-smooth stats or to check Taylor
# jackknife        : deterministic resampling, good for verification
estimate_effort(design, variance = "taylor")
set.seed(123)
estimate_effort(design, variance = "bootstrap")
estimate_effort(design, variance = "jackknife")

# Formal agreement check between analytic and replicate variance. (It works on
# ratio and product estimators — CPUE, HPUE, total catch — so we come back to
# it in ACT 6 once interviews are attached.)

# ---- 5c. What are we expanding TO? -----------------------------------------
# `target` controls the expansion frame. This is a scoping decision, not a
# statistical one, and it is where audiences get confused:
#   "sampled_days"   -> total across days actually surveyed (no extrapolation)
#   "stratum_total"  -> expanded to all days in each stratum
#   "period_total"   -> expanded to the whole season
estimate_effort(design, target = "sampled_days")
estimate_effort(design, target = "stratum_total")
# Look closely: both give 372.5 with the stratum SE collapsing to 0. That is
# not a bug — example_calendar sampled EVERY day, so the expansion factor is 1
# and there is no sampling variability left to estimate. On a real schedule
# (30-50% of days) the two targets differ a lot, and "period_total" is what
# goes in the report. This is why include_all = TRUE in ACT 3 matters: the
# unsampled days must be in the calendar for the expansion to exist.

# ---- 5d. Design diagnostics ------------------------------------------------
summary(design)
audit_strata(design) # sparse strata, singleton PSUs — the things that make
# variance estimation silently unreliable
plot_design(design, title = "Effort distribution by stratum")

# ---- 5e. Escape hatch ------------------------------------------------------
# Nothing is hidden. Pull the survey object and use the survey package directly
# whenever tidycreel does not cover your estimator.
svy <- as_creel_svydesign(design)
class(svy)
survey::svytotal(~effort_hours, svy)


# =============================================================================
# ACT 6 — INTERVIEWS: CPUE, HARVEST, TOTAL CATCH                        (8 min)
# =============================================================================
# add_interviews() maps YOUR columns to creel roles. Map generously — several
# summaries only unlock when the optional roles are supplied.
design <- add_interviews(
  design,
  example_interviews,
  catch = catch_total,
  effort = hours_fished,
  harvest = catch_kept,
  n_anglers = n_anglers, # party size; 1 if rows are single anglers
  trip_status = trip_status, # "complete" / "incomplete"
  trip_duration = trip_duration, # total trip length, not just hours observed
  angler_type = angler_type,
  angler_method = angler_method,
  species_sought = species_sought,
  refused = refused
)
print(design)

# ---- 6a. ROM vs MOR — the fight worth having -------------------------------
# Ratio-of-means (ROM) = sum(catch) / sum(effort)   <- weights by effort
# Mean-of-ratios (MOR) = mean(catch / effort)       <- weights each party equally
catch_v <- c(2, 0, 6, 1, 3, 4, 0, 2, 1, 5)
hours_v <- c(4, 1, 3, 2, 2, 4, 2, 2, 1, 3)
c(ROM = sum(catch_v) / sum(hours_v), MOR = mean(catch_v / hours_v))
# MOR is inflated by short, lucky trips (one fish in 15 minutes = 4 fish/hr).
# tidycreel defaults to ROM, which is what you want for expanding to a total.

cpue <- estimate_catch_rate(design)
print(cpue)

# Side-by-side, with the design-based variance for each. Three estimators:
#   rom        = ratio of means (default)
#   mor        = mean of ratios
#   regression = catch regressed on effort through the origin (Petrere et al.
#                2010) — often the tightest SE, and a good sanity check
compare_cpue_estimators(design)
# On this toy season: ROM 0.97, MOR 1.24, regression 0.80 fish/angler-hour.
# Same data, 55% spread. Whichever you pick, say so in the methods section.

# ---- 6b. Harvest and release ------------------------------------------------
estimate_harvest_rate(design) # HPUE
# Release rate needs species-level catch records (catch_type = "released"),
# so it waits until add_catch() in ACT 7.

# ---- 6c. Totals = rate x effort --------------------------------------------
# Note this is a PRODUCT of two estimates, so the variance combines both
# sources. Do not multiply point estimates by hand.
estimate_total_catch(design)
estimate_total_harvest(design)

# Now compare_variance() has something it can work with: does the Taylor
# linearised SE agree with a jackknife on this ratio?
compare_variance(estimate_catch_rate(design), replicate_method = "jackknife")

# Grouped versions work the same way — but watch this one fail on purpose:
try(estimate_catch_rate(design, by = day_type))
# The example season has only 7 weekend interviews, and tidycreel refuses to
# compute a ratio estimate on n < 10 per group. This is a FEATURE. Reporting a
# CPUE from 7 parties is how a survey ends up defending an indefensible number.
# The fix is a design fix (more days, or collapse the stratum), not an argument.
check_completeness(design) # tells you which cells are too thin
estimate_total_catch(design, by = day_type)

# ---- 6d. Incomplete trips ---------------------------------------------------
# A roving survey intercepts trips mid-way. Using observed hours as if they were
# whole trips biases CPUE. That is why trip_status and trip_duration are mapped.
# It compares the estimate you would get with and without truncating short
# intercepts, so you can see the size of the bias for YOUR data.
try(validate_incomplete_trips(
  design,
  catch = catch_total,
  effort = hours_fished
))
# On this toy season it refuses: only 5 incomplete trips, and the equivalence
# test (TOST) it runs needs at least 10. Same lesson as above — the package
# would rather say "not enough data" than hand you a comfortable number.

# ---- 6e. Angler-level quantities -------------------------------------------
mean_party_size(example_interviews, n_anglers = n_anglers)

# Angler-hours -> angler-trips needs BOTH the effort estimate and the design
# (mean trip length comes from the interviews).
estimate_angler_trips(effort, design)
summarize_trips(design)


# =============================================================================
# ACT 7 — BIOLOGICAL DATA: SPECIES, LENGTHS, AGES                       (5 min)
# =============================================================================
# These tables are LONG and join back to interviews by a shared uid. That join
# is how a fish inherits its interview's survey weight.

design <- add_catch(
  design,
  example_catch,
  catch_uid = interview_id,
  interview_uid = interview_id,
  species = species,
  count = count,
  catch_type = catch_type # caught / harvested / released
)

# Now every catch estimator can be split by species:
estimate_catch_rate(design, by = species)
estimate_total_catch(design, by = species)
estimate_total_harvest(design, by = species)

design <- add_lengths(
  design,
  example_lengths,
  length_uid = interview_id,
  interview_uid = interview_id,
  species = species,
  length = length,
  length_type = length_type,
  count = count,
  release_format = "binned" # harvest measured individually, releases binned
)

# A WEIGHTED length distribution — not a histogram of what the clerk happened
# to measure. This is the payoff of keeping the design attached.
ld <- est_length_distribution(design, by = species, bin_width = 25)
print(ld)
autoplot(ld, theme = "creel")

est_mean_length(ld) # weighted mean length + CI
# CAVEAT for the next two: the constants below are ILLUSTRATIVE. One 380 mm
# minimum and one length-weight pair (a, b) get applied to walleye, bass and
# panfish alike, so the panfish rows are nonsense biologically. In real use,
# subset by species and supply that species' own regulation and a/b.
est_compliance(ld, min_length = 380) # proportion at/above a legal minimum
est_biomass(ld, a = 3.2e-6, b = 3.25) # length-weight -> harvested biomass

design <- add_ages(
  design,
  example_ages,
  age_uid = interview_id,
  interview_uid = interview_id,
  species = species,
  age = age,
  age_type = age_type
)
ad <- est_age_distribution(design, by = species)
print(ad)
est_mean_age(ad)


# =============================================================================
# ACT 8 — DESCRIPTIVE SUMMARIES (NO EXPANSION)                          (3 min)
# =============================================================================
# Managers ask "who was fishing and for what?" long before they ask for totals.
# These summarize_* functions describe the INTERVIEWED SAMPLE only. They are
# deliberately unexpanded — do not report them as season totals.
summarize_refusals(design) # non-response, the number nobody reports
summarize_by_day_type(design)
summarize_by_angler_type(design) # bank / boat
summarize_by_method(design)
summarize_by_species_sought(design)
summarize_successful_parties(design) # proportion catching >= 1 fish
summarize_by_trip_length(design)
summarize_cws_rates(design, by = species_sought) # catch of species sought
summarize_hws_rates(design, by = species_sought) # harvest of species sought
summarize_length_freq(design, type = "harvest", by = species, bin_width = 25)

# Non-response correction, when refusal rates differ by stratum. Note the input
# is a DATA FRAME of counts approached vs responded — not a vector of rates, so
# the adjustment can carry its own uncertainty.
resp <- data.frame(
  stratum = c("weekday", "weekend"),
  n_sampled = c(80L, 60L),
  n_responded = c(72L, 48L) # 90% vs 80% response
)
design_adj <- adjust_nonresponse(design, resp)
attr(design_adj, "nonresponse_diagnostics")


# =============================================================================
# ACT 9 — OTHER SURVEY TYPES                                            (3 min)
# =============================================================================
# Same three-step workflow; `survey_type` changes the estimator underneath.
# Show these fast — the point is coverage, not depth. Each has a vignette.

# ---- 9a. Camera / counter surveys ------------------------------------------
data(example_camera_counts)
data(example_camera_timestamps)

all_dates <- sort(unique(example_camera_counts$date))
cam_calendar <- data.frame(
  date = all_dates,
  day_type = ifelse(
    weekdays(all_dates) %in% c("Saturday", "Sunday"),
    "weekend",
    "weekday"
  )
)

# survey_type = "camera" REQUIRES camera_mode. Omitting it errors on purpose —
# a camera counting entries is a different estimator from a camera snapping
# instantaneous frames, and guessing would be silently wrong.
design_cam <- creel_design(
  cam_calendar,
  date = date,
  strata = day_type,
  survey_type = "camera",
  camera_mode = "counter"
)
print(design_cam)

# Cameras fail. Drop non-operational days explicitly, then let the design
# expand over the gap — never leave a zero where the camera was simply off.
counts_ok <- subset(example_camera_counts, camera_status == "operational")
design_cam <- add_counts(design_cam, counts_ok)
suppressWarnings(print(estimate_effort(design_cam)))

# Ingress/egress timestamps -> angler-hours per day:
preprocess_camera_timestamps(
  example_camera_timestamps,
  date_col = date,
  ingress_col = ingress_time,
  egress_col = egress_time
)

# Missing camera days can also be imputed rather than dropped:
#   impute_camera_counts(); est_effort_camera_mi() propagates imputation error
#   into the variance. See vignette("camera-surveys").

# ---- 9b. Hybrid access + roving --------------------------------------------
# Two effort streams covering fractions of the same population.
access <- data.frame(
  date = as.Date(c("2024-06-03", "2024-06-08", "2024-06-10", "2024-06-15")),
  day_type = c("weekday", "weekend", "weekday", "weekend"),
  count = c(12L, 18L, 9L, 21L)
)
roving <- transform(access, count = c(10L, 16L, 8L, 19L))
hybrid <- as_hybrid_svydesign(
  access_data = access,
  roving_data = roving,
  access_fraction = c(weekday = 0.5, weekend = 0.5),
  roving_fraction = c(weekday = 0.5, weekend = 0.5)
)
hybrid
survey::svytotal(~count, hybrid)

# ---- 9c. Bus-route: PPS site selection -------------------------------------
site_frame <- data.frame(
  site_id = c("North Bay", "South Cove", "Dock Area", "Main Channel"),
  p_site = c(0.35, 0.25, 0.25, 0.15) # selection probs, must sum to 1
)
bus_frame <- generate_bus_schedule(
  schedule = sched_week,
  sampling_frame = site_frame,
  site = site_id,
  p_site = p_site,
  crew = 1
)
head(bus_frame)
# Horvitz-Thompson weights come from get_inclusion_probs(); site shares from
# get_site_contributions(). See vignette("bus-route-surveys").

# Also available, same pattern, own vignettes:
#   ice fishing        : creel_design(..., survey_type = "ice")
#   aerial counts      : estimate_effort_aerial_glmm() (needs glmmTMB/lme4)
#   mark-recapture     : estimate_mr_harvest(), estimate_exploitation_rate(),
#                        estimate_angler_n() (Chapman)
#   spatial sections   : add_sections() + estimate_effort(aggregate_sections=)
#   effort per acre    : estimate_effort_per_acre()
#
# NOT covered today, worth knowing they exist:
#   reallocate_strata(), simulate_strata_collapse()  - fixing thin strata
#   get_sampling_frame(), get_enumeration_counts()   - bus-route internals
#   summarize_by_zip() / summarize_by_county()       - angler origin (zipcodeR)
#   prep_* helpers                                   - raw agency file shaping
#   tidycreel.connect                                - DuckDB/DBI ingestion

# =============================================================================
# ACT 10 — DIAGNOSTICS, PLOTS, EXPORT                                   (3 min)
# =============================================================================
# ---- 10a. Is this survey even estimable? -----------------------------------
check_completeness(design) # cells with too few interviews/counts

# ---- 10b. Compare estimators side by side ----------------------------------
set.seed(123)
cmp <- compare_designs(list(
  Taylor = estimate_effort(design, variance = "taylor"),
  Bootstrap = estimate_effort(design, variance = "bootstrap")
))
print(cmp)
autoplot(cmp)

# ---- 10c. Plots ------------------------------------------------------------
autoplot(effort, title = "Total angler effort")
autoplot(estimate_effort(design, by = day_type), title = "Effort by day type")
autoplot(cpue, title = "CPUE (fish per angler-hour)")

# House style, reusable on your own ggplots:
pal <- creel_palette()
ggplot(example_counts, aes(x = day_type, y = effort_hours)) +
  geom_boxplot(fill = pal[["light"]], colour = pal[["primary"]]) +
  theme_creel() +
  labs(title = "Daily effort by stratum", y = "Angler-hours", x = NULL)

# ---- 10d. Get results OUT ---------------------------------------------------
# tidy() -> a broom-style data frame for tables, joins, and further plotting
generics::tidy(effort)

# One row per estimate across the whole season, ready for a report appendix
season <- season_summary(list(
  effort = effort,
  cpue = cpue,
  total_catch = estimate_total_catch(design),
  total_harvest = estimate_total_harvest(design)
))
season$table

# Both verified below against a temp dir; point them at a real path for a report.
write_estimates(effort, file.path(tempdir(), "effort_2026.csv")) # CSV + metadata header
utils::read.csv(file.path(tempdir(), "effort_2026.csv"), comment.char = "#")
write_schedule(season$table, file.path(tempdir(), "season_2026.xlsx"))


# =============================================================================
# ACT 11 — SIMULATION: CLOSE THE LOOP                                   (1 min)
# =============================================================================
# The best way to learn a design is to sample a population you already know.
# simulate_creel_data() emits schedule/counts/interviews/catch in exactly the
# shapes the add_*() functions expect — so students can test an estimator
# against truth, or dry-run an analysis before the season starts.
params <- list(
  effort = list(gamma_shape = 2.0, gamma_rate = 0.8),
  party = list(mean = 1.5),
  catch_per_trip = list(mean = 1.8, nb_size = 0.5),
  harvest = list(mean_pct = 35),
  counts = list(mean_total_anglers = 10)
)
set.seed(42)
sim <- simulate_creel_data(
  params = params,
  season_days = 90,
  n_sampled_days = 24,
  day_types = c(weekday = 5 / 7, weekend = 2 / 7), # NAMED NUMERIC
  species = c("walleye", "northern_pike"),
  species_weights = c(0.6, 0.4),
  n_counts_per_day = 3L,
  start_date = as.Date("2026-05-01"),
  lat = 40.699, # Kearney, NE -> daylight hours per day
  seed = 42
)
str(sim, max.level = 1)
head(sim$counts)

# day_length() is the expansion factor behind that `lat` argument, and is worth
# knowing on its own: fishable hours change by ~5 h across a Nebraska season.
day_length(40.699, as.Date(c("2026-05-01", "2026-06-21", "2026-09-30")))

# Full round trip on simulated data — this is the exercise to leave them with:
sim_design <- creel_design(sim$schedule, date = date, strata = day_type) |>
  # sim$counts carries total_anglers, daylight_hours AND angler_hours. Hand
  # add_counts() exactly the columns that define the sampling unit plus the one
  # effort measure — angler_hours (= count x daylight T) is already in
  # angler-hours, which is the scale we want to expand.
  add_counts(
    sim$counts[, c("date", "day_type", "count_time", "angler_hours")],
    count_col = angler_hours,
    count_time_col = count_time
  ) |>
  add_interviews(
    sim$interviews,
    catch = catch_total,
    effort = hours_fished,
    harvest = catch_kept,
    n_anglers = n_anglers,
    trip_status = trip_status,
    trip_duration = trip_duration
  )
estimate_effort(sim_design)
estimate_catch_rate(sim_design)
estimate_total_catch(sim_design)

# EXERCISE: raise n_sampled_days from 24 to 60 and re-run. Watch the CI narrow
# roughly as 1/sqrt(n) — the same square-law from ACT 2, now visible.

# =============================================================================
# WHERE TO GO NEXT
# =============================================================================
# vignette(package = "tidycreel")            # full list
# vignette("tidycreel")                      # getting started
# vignette("effort-pipeline")                # count types, expansions, maths
# vignette("catch-pipeline")                 # ROM/MOR, total catch
# vignette("incomplete-trips")               # roving-survey bias
# vignette("survey-scheduling")              # schedules end to end
# vignette("bus-route-surveys")              # PPS designs
# vignette("camera-surveys"); vignette("aerial-surveys"); vignette("ice-fishing")
# vignette("glossary")                       # every term used above
# https://chrischizinski.github.io/tidycreel/
