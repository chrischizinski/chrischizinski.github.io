# Diagnostics example for tidycreel 7.0.0; all observations are simulated.
library(tidycreel)

dates <- seq(as.Date("2024-06-01"), as.Date("2024-06-16"), by = "day")
calendar <- data.frame(
  date = dates,
  day_type = ifelse(
    as.integer(format(dates, "%u")) >= 6L,
    "weekend", "weekday"
  )
)

sample_dates <- as.Date(c(
  "2024-06-03", "2024-06-05", "2024-06-07",
  "2024-06-11", "2024-06-13",
  "2024-06-01", "2024-06-08", "2024-06-15"
))
counts <- data.frame(
  date = sample_dates,
  day_type = c(rep("weekday", 5), rep("weekend", 3)),
  n_anglers = c(10, 12, 11, 14, 13, 20, 24, 22),
  period_hours = 8
)

interviews <- data.frame(
  interview_id = sprintf("trip-%02d", 1:40),
  date = rep(sample_dates, times = c(rep(2, 5), rep(10, 3))),
  day_type = c(rep("weekday", 10), rep("weekend", 30)),
  hours_fished = 2,
  n_anglers = 1L,
  trip_status = "complete",
  catch_total = c(rep(0:4, 2), rep(c(0, 2, 4, 6, 8), 6))
)
interviews$catch_kept <- floor(interviews$catch_total / 2)

catch <- rbind(
  data.frame(
    interview_id = interviews$interview_id,
    species = "bluegill",
    count = interviews$catch_kept,
    catch_type = "harvested"
  ),
  data.frame(
    interview_id = interviews$interview_id,
    species = "bluegill",
    count = interviews$catch_total - interviews$catch_kept,
    catch_type = "released"
  )
)

design <- creel_design(calendar, date = date, strata = day_type) |>
  add_counts(
    counts,
    count_col = n_anglers,
    period_length_col = period_hours
  ) |>
  add_interviews(
    interviews,
    catch = catch_total,
    effort = hours_fished,
    harvest = catch_kept,
    trip_status = trip_status,
    trip_duration = hours_fished,
    n_anglers = n_anglers,
    interview_type = "access"
  ) |>
  add_catch(
    catch,
    catch_uid = interview_id,
    interview_uid = interview_id,
    species = species,
    count = count,
    catch_type = catch_type
  )

# 1. Inspect damaged copies without changing the known teaching fixture.
counts_import <- counts
interviews_import <- interviews
counts_import$n_anglers[1] <- -1
counts_import$date[2] <- as.Date("2024-07-05")
interviews_import$catch_total[2] <- NA_real_

raw_report <- validation_report(
  counts = counts_import,
  interviews = interviews_import,
  na_threshold = 0,
  date_range = range(calendar$date)
)
print(raw_report)
field_report <- validate_creel_data(
  counts = counts_import,
  interviews = interviews_import,
  na_threshold = 0,
  date_range = range(calendar$date)
)
print(subset(as.data.frame(field_report), status != "pass"))

# A default threshold can pass while an individual value is still missing.
default_report <- validate_creel_data(interviews = interviews_import)
print(subset(as.data.frame(default_report), column == "catch_total" & check == "na_rate"))
stopifnot(anyNA(interviews_import$catch_total))

# 2. Calendar dates without counts include intentionally unsampled days.
coverage <- check_completeness(design)
print(coverage$missing_days)
stopifnot(nrow(coverage$missing_days) == 8L)

# This example sampled once per selected day. For multiple visits, use visit IDs.
planned_dates <- data.frame(date = sample_dates)
observed_dates <- unique(counts["date"])
missing_visits <- dplyr::anti_join(planned_dates, observed_dates, by = "date")
stopifnot(nrow(missing_visits) == 0L)

# Simulate a lost count record from a selected day.
counts_missing <- subset(counts, date != as.Date("2024-06-13"))
missing_visits <- dplyr::anti_join(
  planned_dates, unique(counts_missing["date"]), by = "date"
)
print(missing_visits)
stopifnot(nrow(missing_visits) == 1L,
          missing_visits$date == as.Date("2024-06-13"))

# 3. A low-n threshold is a review flag, not a guarantee of precision.
review <- check_completeness(design, n_min = 15L)
print(review$low_n_strata)
stopifnot(review$low_n_strata$key == "weekday",
          review$low_n_strata$n_observed == 10L)

# 4. Check ALL expected strata explicitly, including those with zero rows.
expected_strata <- unique(calendar["day_type"])
weekday_only <- subset(interviews, day_type == "weekday")
observed_n <- dplyr::count(weekday_only, day_type, name = "n_interviews")
interview_coverage <- dplyr::left_join(expected_strata, observed_n, by = "day_type")
interview_coverage$n_interviews[is.na(interview_coverage$n_interviews)] <- 0L
print(interview_coverage)
stopifnot(interview_coverage$n_interviews[interview_coverage$day_type == "weekend"] == 0L)

# For this access design, inspect estimator-eligible trips as well as raw rows.
eligible <- subset(interviews, trip_status == "complete" &
                   !is.na(catch_total) & !is.na(hours_fished) & hours_fished > 0)
print(dplyr::count(eligible, day_type, name = "n_eligible"))

# 5. Zero-catch trips belong in the rate denominator.
# These pooled sample ratios illustrate deletion bias, not the period estimator.
all_trips_rate <- sum(interviews$catch_total) / sum(interviews$hours_fished)
successful <- subset(interviews, catch_total > 0)
successful_only_rate <- sum(successful$catch_total) / sum(successful$hours_fished)
print(data.frame(
  sample = c("All trips", "Successful trips only"),
  fish = c(sum(interviews$catch_total), sum(successful$catch_total)),
  angler_hours = c(sum(interviews$hours_fished), sum(successful$hours_fished)),
  pooled_sample_rate = c(all_trips_rate, successful_only_rate)
))
stopifnot(sum(interviews$catch_total == 0) == 8L,
          all_trips_rate == 1.75, successful_only_rate == 2.1875)

# 6. Reporting requires the matched stratum estimates from the previous post.
total_catch <- estimate_total_catch(design, target = "period_total")
print(total_catch)
stopifnot(abs(total_catch$estimates$estimate - 3072) < 1e-8)
cat("All diagnostics example checks passed.\n")
