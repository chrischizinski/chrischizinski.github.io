# Getting Real Creel Data into tidycreel
# All observations, codes, and field names below are fictional.
# Tested with tidycreel 8.0.0.9000 (cd02a018) and
# tidycreel.connect 0.5.0 (b592b8a). No live service is contacted.
#
# Install current GitHub packages, plus the YAML-profile dependency:
# install.packages("pak")
# pak::pak(c(
#   "chrischizinski/tidycreel",
#   "chrischizinski/tidycreel.connect",
#   "config"
# ))
#
# For the exact versions used for this example:
# pak::pak(c("chrischizinski/tidycreel@cd02a018c044d5aec5ccba605513bd191a7dbed0",
#            "chrischizinski/tidycreel.connect@b592b8a121daf1a9ae9c8f749c132afad7de180f",
#            "config"))

library(tidycreel)
library(tidycreel.connect)

# A fresh directory on every run; existing files are never overwritten.
example_dir <- tempfile("creel-connect-")
dir.create(example_dir)

# The fictional protocol samples two weekday and two weekend dates from
# June 1-9, with equal day-selection probabilities within each stratum.
# On each sampled day the full 08:00-16:00 fishing period is covered,
# with two instantaneous counts. All fishing is from shore.
sample_dates <- as.Date(c("2024-06-01", "2024-06-02",
                          "2024-06-03", "2024-06-04"))
day_type <- function(x) {
  ifelse(as.integer(format(x, "%u")) >= 6L, "weekend", "weekday")
}

raw_interviews <- data.frame(
  TripID = sprintf("trip-%02d", 1:8),
  SurveyDate = rep(sample_dates, each = 2),
  DayType = rep(day_type(sample_dates), each = 2),
  HoursFished = c(2, 3, 1, 2, 2, 4, 3, 2),
  PartySize = c(2, 1, 1, 2, 1, 2, 1, 1),
  TotalFish = c(3, 0, 2, 1, 0, 4, 1, 2),
  TripCode = "C"
)
# HoursFished is elapsed trip duration. TotalFish is the whole party's
# catch. Everyone in a party fished for the full stated duration.
# C means a completed trip interviewed at the access point.

raw_counts <- data.frame(
  SurveyDate = rep(sample_dates, each = 2),
  DayType = rep(day_type(sample_dates), each = 2),
  CountClock = rep(c("10:00", "14:00"), 4),
  ShoreAnglers = c(10, 14, 8, 12, 5, 7, 4, 8),
  FishingBoats = 0,
  OtherBoats = 0
)
# These are observed zeros: this fictional fishery has no boating.

# Catch is species-level detail. The zero-catch trips remain in interviews;
# this fictional export has no catch-detail row for those two trips.
raw_catch <- data.frame(
  CatchID = sprintf("catch-%02d", 1:7),
  TripID = c("trip-01", "trip-01", "trip-03", "trip-04",
             "trip-06", "trip-07", "trip-08"),
  Species = c("bluegill", "yellow_perch", rep("bluegill", 5)),
  FishCount = c(2, 1, 2, 1, 4, 1, 2),
  CatchCode = "K"
)
# K means harvested; all fish in this fictional example were kept.

raw_harvest_lengths <- data.frame(
  MeasurementID = c("length-01", "length-02"),
  TripID = c("trip-01", "trip-01"),
  Species = c("bluegill", "yellow_perch"),
  LengthMM = c(180, 230),
  LengthCode = "H"
)
# Two fish were measured; length records do not enumerate the whole catch.
# No release lengths were collected: an empty table retains the headers.
raw_release_lengths <- raw_harvest_lengths[0, ]

raw_tables <- list(
  interviews = raw_interviews, counts = raw_counts, catch = raw_catch,
  harvest_lengths = raw_harvest_lengths,
  release_lengths = raw_release_lengths
)
csv_paths <- file.path(example_dir, paste0(names(raw_tables), ".csv"))
names(csv_paths) <- names(raw_tables)
for (table in names(raw_tables)) {
  write.csv(raw_tables[[table]], csv_paths[[table]], row.names = FALSE)
}

# Use absolute paths so this profile works from any working directory.
profile_lines <- c(
  "default:",
  "  backend: csv",
  "  files:",
  sprintf('    %s: "%s"', names(csv_paths), csv_paths),
  "  schema:",
  "    survey_type: instantaneous",
  "    columns:",
  "      interview_uid: TripID",
  "      date: SurveyDate",
  "      effort: HoursFished",
  "      n_anglers: PartySize",
  "      catch: TotalFish",
  "      trip_status: TripCode",
  "      count_time: CountClock",
  "      bank_anglers: ShoreAnglers",
  "      angler_boats: FishingBoats",
  "      non_ang_boats: OtherBoats",
  "      catch_uid: CatchID",
  "      species: Species",
  "      catch_count: FishCount",
  "      catch_type: CatchCode",
  "      length_uid: MeasurementID",
  "      length_mm: LengthMM",
  "      length_type: LengthCode",
  "    strata_cols:",
  "      day_type: DayType",
  "    value_maps:",
  "      trip_status:",
  '        "C": complete',
  "      catch_type:",
  '        "K": harvested',
  "      length_type:",
  '        "H": harvest'
)
profile_path <- file.path(example_dir, "creel-config.yml")
writeLines(profile_lines, profile_path)

# The same profile is reusable with another export that follows this contract.
conn <- creel_connect_from_yaml(profile_path)
interviews <- fetch_interviews(conn)
counts <- fetch_counts(conn)
catch_data <- fetch_catch(conn)
harvest_lengths <- fetch_harvest_lengths(conn)
release_lengths <- fetch_release_lengths(conn)

print(interviews[, c("interview_uid", "effort", "n_anglers",
                     "catch_count", "trip_status")])
print(data.frame(
  table = names(raw_tables),
  source_rows = vapply(raw_tables, nrow, integer(1)),
  fetched_rows = c(nrow(interviews), nrow(counts), nrow(catch_data),
                   nrow(harvest_lengths), nrow(release_lengths)),
  row.names = NULL
))

# These checks use known facts about the fictional export, not a blanket
# rule that every missing catch row in a real database means zero catch.
stopifnot(
  nrow(interviews) == 8L,
  nrow(counts) == 8L,
  sum(interviews$catch_count == 0) == 2L,
  identical(interviews$interview_uid, raw_interviews$TripID),
  identical(counts$count_time, raw_counts$CountClock),
  all(catch_data$interview_uid %in% interviews$interview_uid),
  all(harvest_lengths$interview_uid %in% interviews$interview_uid),
  all(interviews$trip_status == "complete"),
  sum(catch_data$catch_count) == sum(interviews$catch_count),
  nrow(release_lengths) == 0L
)

# Demonstrate the difference between a measured zero and unknown catch.
# This is a separate demonstration copy; it does not feed the design below.
unknown_source <- raw_interviews
unknown_source$TotalFish[2] <- NA_real_
unknown_path <- file.path(example_dir, "interviews-unknown.csv")
write.csv(unknown_source, unknown_path, row.names = FALSE)
unknown_profile <- profile_lines
unknown_profile[grepl("^    interviews:", unknown_profile)] <-
  sprintf('    interviews: "%s"', unknown_path)
unknown_profile_path <- file.path(example_dir, "unknown-config.yml")
writeLines(unknown_profile, unknown_profile_path)
unknown_interviews <- fetch_interviews(
  creel_connect_from_yaml(unknown_profile_path)
)
stopifnot(is.na(unknown_interviews$catch_count[2]))

# The full calendar comes from the sampling plan, not the observed dates.
dates <- seq(as.Date("2024-06-01"), as.Date("2024-06-09"), by = "day")
calendar <- data.frame(date = dates, day_type = day_type(dates))
# All sampled days cover the full 8-hour period; there is no shift draw.
counts$period_hours <- 8

design <- creel_design(calendar, date = date, strata = day_type) |>
  add_counts(
    counts,
    count_col = bank_anglers,
    count_time_col = count_time,
    period_length_col = period_hours,
    p_period = 1
  ) |>
  add_interviews(
    interviews,
    catch = catch_count,
    effort = effort,
    trip_status = trip_status,
    trip_duration = effort,
    n_anglers = n_anglers,
    interview_type = "access"
  ) |>
  add_catch(
    catch_data,
    catch_uid = interview_uid,
    interview_uid = interview_uid,
    species = species,
    count = catch_count,
    catch_type = catch_type
  )

# Attach measured fish separately, using the interview link on both sides.
design <- add_lengths(
  design, harvest_lengths,
  length_uid = interview_uid, interview_uid = interview_uid,
  species = species, length = length_mm, length_type = length_type
)

stopifnot(inherits(design, "creel_design"), nrow(design$calendar) == 9L)
print(design)
cat("\nExample files:", example_dir, "\n")
cat("Versions:", as.character(packageVersion("tidycreel")), "/",
    as.character(packageVersion("tidycreel.connect")), "\n")
# No estimate is calculated here. Continue with the series' diagnostics and
# estimation posts after confirming the design matches the field protocol.
