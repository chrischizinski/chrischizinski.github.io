# Counts and interviews: an illustrative model, not observed fishery data.
# Run: Rscript assets/code/tidycreel_counts_interviews.R [output-directory]
# Requires ggplot2. No tidycreel installation needed.
set.seed(426)
n_days_season <- 60
n_sampled <- 20
shift_hours <- 8
anglers_mean <- c(morning = 10, evening = 10)
rate_true <- c(morning = 0.2, evening = 0.6)
catch_target <- n_days_season * sum(anglers_mean * shift_hours * rate_true)

# Equal-probability, completed, single-angler trips confined to one shift.
interview_rate <- function(shifts, per_day = 15) {
  shift <- rep(shifts, each = per_day)
  hours <- runif(length(shift), 1, 5)
  fish <- rpois(length(shift), rate_true[shift] * hours)
  sum(fish) / sum(hours)
}

one_season <- function() {
  count_shift <- sample(names(anglers_mean), n_sampled, replace = TRUE)
  counts <- rpois(n_sampled, anglers_mean[count_shift])
  effort_hat <- n_days_season * mean(counts * shift_hours / 0.5)
  rates <- c(
    "Same shift" = interview_rate(count_shift),
    "Morning only" = interview_rate(rep("morning", n_sampled)),
    "Independent sample" = interview_rate(
      sample(names(anglers_mean), n_sampled, replace = TRUE)
    )
  )
  effort_hat * rates
}

sims <- t(replicate(2000, one_season()))
results <- data.frame(
  Plan = colnames(sims),
  Mean = round(colMeans(sims)),
  Percent = round(100 * colMeans(sims) / catch_target, 1),
  SD = round(apply(sims, 2, sd)),
  row.names = NULL
)
print(results)

library(ggplot2)
plan_levels <- c("Same shift", "Morning only", "Independent sample")
plot_data <- data.frame(
  plan = factor(rep(colnames(sims), each = nrow(sims)), levels = plan_levels),
  catch = as.vector(sims)
)
plot_totals <- ggplot(plot_data, aes(x = catch, y = plan, fill = plan)) +
  geom_vline(xintercept = catch_target, linetype = "dashed", colour = "#243a45") +
  geom_boxplot(width = 0.48, outlier.shape = NA, linewidth = 0.6) +
  scale_fill_manual(values = c("#407b83", "#c17a49", "#6b7f98")) +
  scale_x_continuous(labels = scales::label_comma()) +
  coord_cartesian(xlim = c(0, 6000)) +
  labs(x = "Estimated season catch (fish)", y = NULL,
       title = "Missing the evening bite",
       subtitle = "2,000 simulations · dashed line: model target of 3,840 fish",
       caption = "Boxes: middle 50%; line: median; whiskers: up to 1.5 × IQR. Outliers hidden.") +
  theme_minimal(base_size = 14) +
  theme(legend.position = "none", panel.grid.major.y = element_blank(),
        panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold", colour = "#243a45"),
        plot.caption = element_text(size = 10, hjust = 0),
        plot.background = element_rect(fill = "#faf8f3", colour = NA),
        plot.margin = margin(18, 24, 18, 18))

shift_data <- data.frame(
  shift = factor(c("Morning\n06:00–14:00", "Evening\n14:00–22:00"),
                 levels = c("Morning\n06:00–14:00", "Evening\n14:00–22:00")),
  rate = unname(rate_true)
)
plot_rates <- ggplot(shift_data, aes(shift, rate, fill = shift)) +
  geom_col(width = 0.5) +
  geom_text(aes(label = sprintf("%.1f fish / angler-hour", rate)),
            vjust = -0.7, size = 4.8, colour = "#243a45") +
  scale_fill_manual(values = c("#c17a49", "#407b83")) +
  scale_y_continuous(limits = c(0, 0.75), breaks = c(0, 0.2, 0.4, 0.6)) +
  labs(x = NULL, y = "Catch rate (fish per angler-hour)",
       title = "Same effort. Different catch rates.",
       subtitle = "Illustrative assumptions: 10 anglers on average in each eight-hour shift") +
  theme_minimal(base_size = 14) +
  theme(legend.position = "none", panel.grid.major.x = element_blank(),
        panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold", colour = "#243a45"),
        plot.background = element_rect(fill = "#faf8f3", colour = NA),
        plot.margin = margin(18, 24, 18, 18))

args <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(args)) args[1] else "counts-interviews-output"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
ggsave(file.path(output_dir, "tidycreel-counts-interviews-rates.png"),
       plot_rates, width = 10, height = 5.5, dpi = 180)
ggsave(file.path(output_dir, "tidycreel-counts-interviews-totals.png"),
       plot_totals, width = 10, height = 5, dpi = 180)
write.csv(results, file.path(output_dir, "tidycreel-counts-interviews-results.csv"),
          row.names = FALSE)
