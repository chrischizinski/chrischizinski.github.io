# Worked example for tidycreel 7.0.0; all observations are simulated.
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

estimate_catch_rate(design, by = day_type)
estimate_harvest_rate(design, by = day_type)
estimate_release_rate(design, by = day_type)

total_catch <- estimate_total_catch(design, target = "period_total")
total_harvest <- estimate_total_harvest(design, target = "period_total")
total_release <- estimate_total_release(design, target = "period_total")

total_catch
total_harvest
total_release
