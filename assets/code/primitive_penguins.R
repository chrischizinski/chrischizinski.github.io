# primitive_penguins.R
#
# Rebuild Allison Horst's Palmer penguins artwork from geometric primitives,
# in the spirit of Michael Fogleman's primitive:
# https://github.com/fogleman/primitive
#
# The algorithm:
#   1. Fill a canvas with the target image's average colour.
#   2. Propose random shapes and score their pixel-level error.
#   3. Hill-climb the best proposal through small random mutations.
#   4. Calculate the best fill colour directly for each proposed shape.
#   5. Paint the shape only if it lowers error, then repeat.
#
# The search uses a downsampled raster for speed. Accepted shapes are retained
# as vector polygon data and drawn with ggplot2 at the requested output size.
#
# PREREQUISITES
# - R 4.1 or newer (for the native pipe and short anonymous functions)
# - tidyverse 2.0.0 or newer
# - png, progress, gganimate, and gifski
#
# Install the packages once with:
# install.packages(c("tidyverse", "png", "progress", "gganimate", "gifski"))
#
# HOW TO RUN
# 1. Save this script in an empty project folder.
# 2. Set that folder as the working directory.
# 3. Source the script or run: Rscript primitive_penguins.R
#
# Paths below are relative to the working directory. The default 1,000-shape
# search takes about 2-3 minutes on the computer used for this post. For a
# quick first test, use the smoke-test settings shown in the parameter section.
# Existing output files with the same run ID will be overwritten.

# ---- packages ---------------------------------------------------------------

library(tidyverse)
library(png)
library(gganimate)

# ---- parameters -------------------------------------------------------------

image_path <- "data/lter_penguins.png"

# Pin the artwork to the commit that introduced this file. Pinning avoids a
# future change on the main branch altering a supposedly reproducible run.
image_url <- paste0(
  "https://raw.githubusercontent.com/allisonhorst/palmerpenguins/",
  "8e1061dc0b3d0cbb53bea0545f651950b2109dca/",
  "man/figures/lter_penguins.png"
)
image_md5 <- "294f95f2d596414de70edc35dbe6d0fe"

main_seed <- 2026
n_shapes <- 1000
shape_type <- "triangle" # triangle, ellipse, rectangle, or mixed
shape_alpha <- 0.5       # valid range: greater than 0 and no more than 1
work_width <- 300        # width, in pixels, used during the search
n_candidates <- 50       # random starting shapes tried per candidate batch
max_age <- 100           # failed mutations allowed before hill climbing stops
max_candidate_batches <- 25 # batches tried before ending a converged search
ellipse_vertices <- 60   # polygon vertices used to score and draw ellipses
bg_fill <- "white"       # transparent PNG pixels are composited onto this

# QUICK SMOKE TEST
# Uncomment these values to verify the workflow in a few seconds before a
# full-quality run:
# n_shapes <- 20
# work_width <- 100
# n_candidates <- 10
# max_age <- 20

# OPTIONAL MULTI-SEED EXPERIMENT
# Set PRIMITIVE_SEED_GIF=true before sourcing the script to fit the image
# repeatedly and animate the completed reconstructions. For example:
# Sys.setenv(PRIMITIVE_SEED_GIF = "true")
# source("primitive_penguins.R")
make_seed_variation_gif <- identical(
  tolower(Sys.getenv("PRIMITIVE_SEED_GIF", unset = "false")),
  "true"
)
variation_seeds <- c(main_seed, 17, 101, 503, 867, 9001)
variation_n_shapes <- 400

# ---- validate parameters ----------------------------------------------------

is_positive_whole <- function(x) {
  length(x) == 1 && is.finite(x) && x > 0 && x == floor(x)
}

is_nonnegative_whole <- function(x) {
  length(x) == 1 && is.finite(x) && x >= 0 && x == floor(x)
}

allowed_shape_types <- c("triangle", "ellipse", "rectangle", "mixed")
shape_type <- match.arg(shape_type, allowed_shape_types)

if (!is_positive_whole(main_seed)) {
  stop("main_seed must be one positive whole number.", call. = FALSE)
}
if (!is_positive_whole(n_shapes)) {
  stop("n_shapes must be one positive whole number.", call. = FALSE)
}
if (!is.numeric(shape_alpha) || length(shape_alpha) != 1 ||
      !is.finite(shape_alpha) || shape_alpha <= 0 || shape_alpha > 1) {
  stop("shape_alpha must be greater than 0 and no more than 1.", call. = FALSE)
}

whole_number_parameters <- list(
  work_width = work_width,
  n_candidates = n_candidates,
  max_candidate_batches = max_candidate_batches,
  ellipse_vertices = ellipse_vertices
)

invalid_whole_parameters <- names(whole_number_parameters)[
  !map_lgl(whole_number_parameters, is_positive_whole)
]

if (length(invalid_whole_parameters) > 0) {
  stop(
    "These parameters must be positive whole numbers: ",
    str_c(invalid_whole_parameters, collapse = ", "),
    ".",
    call. = FALSE
  )
}
if (!is_nonnegative_whole(max_age)) {
  stop("max_age must be one nonnegative whole number.", call. = FALSE)
}
if (ellipse_vertices < 8) {
  stop("ellipse_vertices must be at least 8.", call. = FALSE)
}

bg_rgb <- tryCatch(
  col2rgb(bg_fill)[, 1] / 255,
  error = \(e) {
    stop("bg_fill is not a color understood by R.", call. = FALSE)
  }
)

if (make_seed_variation_gif) {
  if (any(!map_lgl(as.list(variation_seeds), is_positive_whole))) {
    stop("Every variation seed must be a positive whole number.", call. = FALSE)
  }
  if (anyDuplicated(variation_seeds)) {
    stop("variation_seeds must not contain duplicates.", call. = FALSE)
  }
  if (!main_seed %in% variation_seeds) {
    stop("variation_seeds must include main_seed.", call. = FALSE)
  }
  if (!is_positive_whole(variation_n_shapes) ||
        variation_n_shapes > n_shapes) {
    stop(
      "variation_n_shapes must be positive and no larger than n_shapes.",
      call. = FALSE
    )
  }
}

# ---- obtain and validate the source image ----------------------------------

download_source_image <- function(url, destination, expected_md5) {
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  temporary_file <- tempfile(fileext = ".png")
  on.exit(unlink(temporary_file), add = TRUE)

  download.file(url, temporary_file, mode = "wb", quiet = TRUE)
  observed_md5 <- unname(tools::md5sum(temporary_file))

  if (!identical(observed_md5, expected_md5)) {
    stop(
      "The downloaded image did not match the expected checksum.",
      call. = FALSE
    )
  }

  copied <- file.copy(temporary_file, destination, overwrite = TRUE)
  if (!copied) {
    stop("The source image could not be saved to ", destination, ".")
  }
}

if (!file.exists(image_path)) {
  download_source_image(image_url, image_path, image_md5)
}

observed_md5 <- unname(tools::md5sum(image_path))
if (!identical(observed_md5, image_md5)) {
  stop(
    image_path,
    " does not match the pinned source image. Remove it and rerun the script.",
    call. = FALSE
  )
}

img <- readPNG(image_path)
img_dims <- dim(img)

if (length(img_dims) != 3 || !img_dims[3] %in% c(3, 4)) {
  stop("The source PNG must have RGB or RGBA color channels.", call. = FALSE)
}
if (!is.numeric(img) || any(!is.finite(img))) {
  stop("The source PNG contains invalid color values.", call. = FALSE)
}

# RGB images are fully opaque. RGBA images supply their own alpha channel.
img_alpha <- if (img_dims[3] == 4) {
  img[, , 4]
} else {
  matrix(1, nrow = img_dims[1], ncol = img_dims[2])
}
img_rgb <- img[, , 1:3, drop = FALSE]

# ---- downsample the target image -------------------------------------------

# The original PNG is 1,800 pixels wide. Searching every original pixel would
# be slow and unnecessary for a geometric approximation, so neighboring pixels
# are averaged into block x block cells.
block <- ceiling(img_dims[2] / work_width)

# R stores matrices in column-major order. The y-then-x construction below
# preserves that same order, so row i of target matches pixel index i later.
target_tbl <- tibble(
  y = rep(seq_len(img_dims[1]), times = img_dims[2]),
  x = rep(seq_len(img_dims[2]), each = img_dims[1]),
  a = as.vector(img_alpha),
  r = as.vector(img_rgb[, , 1]) * a + bg_rgb[1] * (1 - a),
  g = as.vector(img_rgb[, , 2]) * a + bg_rgb[2] * (1 - a),
  b = as.vector(img_rgb[, , 3]) * a + bg_rgb[3] * (1 - a)
) |>
  mutate(
    x = (x - 1) %/% block + 1,
    y = (y - 1) %/% block + 1
  ) |>
  summarise(across(c(r, g, b), mean), .by = c(x, y)) |>
  arrange(x, y)

w <- max(target_tbl$x)
h <- max(target_tbl$y)
target <- target_tbl |>
  select(r, g, b) |>
  as.matrix()

target_plot <- target_tbl |>
  ggplot(aes(x, y, fill = rgb(r, g, b))) +
  geom_raster() +
  scale_fill_identity() +
  scale_y_reverse() +
  coord_fixed(expand = FALSE) +
  theme_void() +
  labs(title = str_glue("Target at working resolution ({w} x {h})"))

if (interactive()) {
  print(target_plot)
}

# Store shared search settings together and pass them explicitly. This makes
# each function's dependencies visible and allows the same fitter to be reused
# for the multi-seed experiment.
context <- list(
  target = target,
  w = w,
  h = h,
  shape_type = shape_type,
  shape_alpha = shape_alpha,
  jitter_sd = w / 16,
  n_candidates = n_candidates,
  max_age = max_age,
  max_candidate_batches = max_candidate_batches,
  ellipse_vertices = ellipse_vertices,
  background_rgb = colMeans(target)
)

# ---- shape geometry ---------------------------------------------------------

rotate_points <- function(x, y, angle, cx, cy) {
  tibble(
    x = cx + x * cos(angle) - y * sin(angle),
    y = cy + x * sin(angle) + y * cos(angle)
  )
}

random_shape <- function(context, type = context$shape_type) {
  if (type == "mixed") {
    type <- sample(c("triangle", "ellipse", "rectangle"), 1)
  }

  cx <- runif(1, 1, context$w)
  cy <- runif(1, 1, context$h)
  radius <- context$w * 0.15

  params <- switch(
    type,
    triangle = c(
      x1 = cx,
      y1 = cy,
      x2 = cx + runif(1, -radius, radius),
      y2 = cy + runif(1, -radius, radius),
      x3 = cx + runif(1, -radius, radius),
      y3 = cy + runif(1, -radius, radius)
    ),
    ellipse = c(
      cx = cx,
      cy = cy,
      rx = runif(1, 1, radius),
      ry = runif(1, 1, radius),
      angle = runif(1, 0, pi)
    ),
    rectangle = c(
      cx = cx,
      cy = cy,
      half_width = runif(1, 1, radius),
      half_height = runif(1, 1, radius),
      angle = runif(1, 0, pi)
    )
  )

  list(type = type, params = params)
}

mutate_shape <- function(shape, context) {
  params <- shape$params

  if (shape$type == "triangle") {
    # Pick one of the three vertices, then move both its x and y coordinates.
    first_coordinate <- sample(0:2, 1) * 2 + 1
    selected <- first_coordinate:(first_coordinate + 1)
    params[selected] <- params[selected] +
      rnorm(2, sd = context$jitter_sd)
  } else {
    parameter_group <- sample(c("center", "size", "angle"), 1)

    if (parameter_group == "center") {
      params[1:2] <- params[1:2] + rnorm(2, sd = context$jitter_sd)
    }
    if (parameter_group == "size") {
      params[3:4] <- pmax(
        params[3:4] + rnorm(2, sd = context$jitter_sd / 2),
        1
      )
    }
    if (parameter_group == "angle") {
      params[5] <- params[5] + rnorm(1, sd = 0.3)
    }
  }

  shape$params <- params
  shape
}

shape_polygon <- function(shape, context) {
  params <- shape$params

  switch(
    shape$type,
    triangle = tibble(
      x = params[c(1, 3, 5)],
      y = params[c(2, 4, 6)]
    ),
    ellipse = {
      angles <- seq(
        0,
        2 * pi,
        length.out = context$ellipse_vertices + 1
      )[-1]

      rotate_points(
        params["rx"] * cos(angles),
        params["ry"] * sin(angles),
        params["angle"],
        params["cx"],
        params["cy"]
      )
    },
    rectangle = rotate_points(
      c(-1, 1, 1, -1) * params["half_width"],
      c(-1, -1, 1, 1) * params["half_height"],
      params["angle"],
      params["cx"],
      params["cy"]
    )
  )
}

# Convert a convex polygon to the linear indices of working-pixel centers that
# fall inside it. A point is inside when it does not lie on opposing sides of
# the polygon's edges.
rasterize <- function(poly, context) {
  x_min <- max(1, ceiling(min(poly$x)))
  x_max <- min(context$w, floor(max(poly$x)))
  y_min <- max(1, ceiling(min(poly$y)))
  y_max <- min(context$h, floor(max(poly$y)))

  if (x_min > x_max || y_min > y_max) {
    return(integer(0))
  }

  xs <- seq.int(x_min, x_max)
  ys <- seq.int(y_min, y_max)
  px <- rep(xs, each = length(ys))
  py <- rep(ys, times = length(xs))

  x1 <- poly$x
  y1 <- poly$y
  x2 <- lead(x1, default = x1[1])
  y2 <- lead(y1, default = y1[1])
  positive_side <- logical(length(px))
  negative_side <- logical(length(px))

  for (edge in seq_along(x1)) {
    cross_product <-
      (x2[edge] - x1[edge]) * (py - y1[edge]) -
      (y2[edge] - y1[edge]) * (px - x1[edge])

    positive_side <- positive_side | cross_product > 0
    negative_side <- negative_side | cross_product < 0
  }

  inside <- !(positive_side & negative_side)
  as.integer((px[inside] - 1) * context$h + py[inside])
}

# ---- score and improve candidate shapes ------------------------------------

# Painting a color over the current canvas with opacity alpha gives:
# new_pixel = current_pixel * (1 - alpha) + color * alpha
#
# Least squares gives the best color directly, so the search only needs to
# optimize a shape's geometry. Only covered pixels can change, which lets us
# update the total sum of squared errors (SSE) without rescoring the full image.
evaluate_shape <- function(shape, current, sse, context) {
  pixel_indices <- rasterize(shape_polygon(shape, context), context)

  if (length(pixel_indices) == 0) {
    return(NULL)
  }

  current_pixels <- current[pixel_indices, , drop = FALSE]
  target_pixels <- context$target[pixel_indices, , drop = FALSE]

  best_color <- colMeans(
    (target_pixels - current_pixels) / context$shape_alpha + current_pixels
  ) |>
    pmax(0) |>
    pmin(1)

  new_pixels <-
    current_pixels * (1 - context$shape_alpha) +
    rep(best_color, each = length(pixel_indices)) * context$shape_alpha

  new_sse <-
    sse - sum((target_pixels - current_pixels)^2) +
    sum((target_pixels - new_pixels)^2)

  list(
    shape = shape,
    pixel_indices = pixel_indices,
    color = best_color,
    new_pixels = new_pixels,
    sse = new_sse
  )
}

best_shape <- function(current, sse, context) {
  # A batch can contain shapes that miss every working pixel. Retry a bounded
  # number of batches rather than passing an empty result into hill climbing.
  for (batch in seq_len(context$max_candidate_batches)) {
    candidates <- map(
      seq_len(context$n_candidates),
      \(candidate) {
        evaluate_shape(random_shape(context), current, sse, context)
      }
    ) |>
      compact()

    if (length(candidates) == 0) {
      next
    }

    best <- reduce(
      candidates,
      \(candidate_a, candidate_b) {
        if (candidate_b$sse < candidate_a$sse) candidate_b else candidate_a
      }
    )

    age <- 0
    while (age < context$max_age) {
      trial <- evaluate_shape(
        mutate_shape(best$shape, context),
        current,
        sse,
        context
      )

      if (!is.null(trial) && trial$sse < best$sse) {
        best <- trial
        age <- 0
      } else {
        age <- age + 1
      }
    }

    # The unchanged canvas is the no-op candidate. Paint only a shape that is
    # strictly better; otherwise try a fresh batch.
    if (is.finite(best$sse) && best$sse < sse) {
      return(best)
    }
  }

  NULL
}

rmse <- function(sse, context) {
  sqrt(sse / length(context$target))
}

# ---- fit one complete reconstruction ---------------------------------------

fit_primitive <- function(
    seed_value,
    n_shapes_to_add,
    context,
    show_progress = TRUE) {
  set.seed(seed_value)

  current <- matrix(
    context$background_rgb,
    nrow = nrow(context$target),
    ncol = 3,
    byrow = TRUE
  )
  sse <- sum((context$target - current)^2)
  accepted_shapes <- vector("list", n_shapes_to_add)
  history <- tibble(step = 0L, rmse = rmse(sse, context))

  progress_bar <- NULL
  if (show_progress) {
    progress_bar <- progress::progress_bar$new(
      total = n_shapes_to_add,
      format = "shape :current/:total [:bar] rmse :rmse eta :eta",
      show_after = 0
    )
  }

  accepted <- 0L
  for (shape_number in seq_len(n_shapes_to_add)) {
    best <- best_shape(current, sse, context)

    if (is.null(best)) {
      message(
        "No improving shape found after ",
        context$max_candidate_batches,
        " candidate batches; stopping after ",
        accepted,
        " accepted shapes."
      )
      break
    }

    accepted <- accepted + 1L
    current[best$pixel_indices, ] <- best$new_pixels
    sse <- best$sse
    accepted_shapes[[accepted]] <- best[c("shape", "color")]
    history <- add_row(history, step = accepted, rmse = rmse(sse, context))

    if (show_progress) {
      progress_bar$tick(
        tokens = list(rmse = sprintf("%.4f", rmse(sse, context)))
      )
    }
  }

  if (accepted == 0L) {
    stop("The search ended without accepting a shape.", call. = FALSE)
  }

  accepted_shapes <- accepted_shapes[seq_len(accepted)]

  shape_tbl <- tibble(
    id = seq_along(accepted_shapes),
    type = map_chr(accepted_shapes, \(item) item$shape$type),
    fill = map_chr(
      accepted_shapes,
      \(item) rgb(item$color[1], item$color[2], item$color[3])
    ),
    polygon = map(
      accepted_shapes,
      \(item) shape_polygon(item$shape, context)
    )
  ) |>
    unnest(polygon) |>
    mutate(
      seed = seed_value,
      alpha = context$shape_alpha,
      canvas_width = context$w,
      canvas_height = context$h,
      y = context$h + 1 - y,
      .before = 1
    )

  # These are executable documentation checks. Any failure indicates a bug,
  # not a disappointing artistic result.
  stopifnot(
    all(is.finite(shape_tbl$x)),
    all(is.finite(shape_tbl$y)),
    all(is.finite(history$rmse)),
    all(diff(history$rmse) <= sqrt(.Machine$double.eps))
  )

  list(
    shape_tbl = shape_tbl,
    history = history,
    n_shapes = accepted,
    final_rmse = tail(history$rmse, 1)
  )
}

# ---- run the main reconstruction -------------------------------------------

main_fit <- fit_primitive(
  seed_value = main_seed,
  n_shapes_to_add = n_shapes,
  context = context,
  show_progress = TRUE
)

shape_tbl <- main_fit$shape_tbl
history <- main_fit$history

# ---- static plots -----------------------------------------------------------

plot_primitive <- function(data, context) {
  ggplot(data, aes(x, y, group = id, fill = fill)) +
    geom_polygon(alpha = context$shape_alpha, colour = NA) +
    scale_fill_identity() +
    coord_fixed(
      xlim = c(0.5, context$w + 0.5),
      ylim = c(0.5, context$h + 0.5),
      expand = FALSE
    ) +
    theme_void() +
    theme(
      panel.background = element_rect(
        fill = rgb(
          context$background_rgb[1],
          context$background_rgb[2],
          context$background_rgb[3]
        ),
        colour = NA
      )
    )
}

final_plot <- plot_primitive(shape_tbl, context)

shape_label <- switch(
  shape_type,
  triangle = "triangles",
  ellipse = "ellipses",
  rectangle = "rectangles",
  mixed = "shapes"
)

steps <- unique(c(10, 50, 100, 200, main_fit$n_shapes)) |>
  keep(\(step) step <= main_fit$n_shapes)

progress_plot <- map(
  steps,
  \(step) mutate(filter(shape_tbl, id <= step), step = step)
) |>
  list_rbind() |>
  mutate(step = fct_inorder(str_glue("{step} {shape_label}"))) |>
  plot_primitive(context) +
  facet_wrap(~step, ncol = 2) +
  theme(strip.text = element_text(size = 12, margin = margin(4, 0, 4, 0)))

error_plot <- history |>
  ggplot(aes(step, rmse)) +
  geom_line() +
  labs(x = "Shapes added", y = "RMSE versus target") +
  theme_minimal()

if (interactive()) {
  print(final_plot)
  print(progress_plot)
  print(error_plot)
}

# ---- animate the build-up ---------------------------------------------------

# Geometric spacing gives early decisions their own frames, then adds later
# fine-detail shapes in larger batches. The original remains in the right pane.
frame_steps <- unique(round(
  main_fit$n_shapes^seq(0, 1, length.out = 80)
))

build_up_data <- shape_tbl |>
  mutate(
    frame = frame_steps[
      findInterval(id, frame_steps, left.open = TRUE) + 1
    ]
  )

alpha_3d <- array(img_alpha, dim = c(img_dims[1:2], 3))
background_3d <- array(
  rep(bg_rgb, each = prod(img_dims[1:2])),
  dim = c(img_dims[1:2], 3)
)
original_rgb <- img_rgb * alpha_3d + background_3d * (1 - alpha_3d)

gap <- context$w * 0.04
right_x <- c(context$w + gap, 2 * context$w + gap) + 0.5

build_up <- build_up_data |>
  ggplot(aes(x, y, group = id, fill = fill)) +
  annotate(
    "rect",
    xmin = 0.5,
    xmax = context$w + 0.5,
    ymin = 0.5,
    ymax = context$h + 0.5,
    fill = rgb(
      context$background_rgb[1],
      context$background_rgb[2],
      context$background_rgb[3]
    )
  ) +
  geom_polygon(alpha = context$shape_alpha, colour = NA) +
  # Some shapes cross the canvas boundary. This rectangle hides their overflow
  # so they cannot spill into the white gap or the reference image.
  annotate(
    "rect",
    xmin = context$w + 0.5,
    xmax = Inf,
    ymin = -Inf,
    ymax = Inf,
    fill = "white"
  ) +
  annotation_raster(
    original_rgb,
    xmin = right_x[1],
    xmax = right_x[2],
    ymin = 0.5,
    ymax = context$h + 0.5
  ) +
  scale_fill_identity() +
  coord_fixed(
    xlim = c(0.5, right_x[2]),
    ylim = c(0.5, context$h + 0.5),
    expand = FALSE
  ) +
  labs(
    title = str_glue("{{current_frame}} {shape_label}"),
    caption = "Right: original artwork by Allison Horst (@allison_horst)"
  ) +
  theme_void() +
  theme(
    plot.background = element_rect(fill = "white", colour = NA),
    plot.margin = margin(0, 12, 0, 12),
    plot.title = element_text(
      hjust = 0,
      size = 16,
      margin = margin(6, 0, 6, 0)
    ),
    plot.caption = element_text(
      hjust = 1,
      size = 10,
      colour = "grey40",
      margin = margin(6, 0, 4, 0)
    )
  ) +
  transition_manual(frame, cumulative = TRUE)

end_pause_frames <- 24
build_up_gif <- animate(
  build_up,
  nframes = length(frame_steps) + end_pause_frames,
  fps = 12,
  end_pause = end_pause_frames,
  width = 1400,
  height = round(1400 * context$h / right_x[2]) + 70,
  renderer = gifski_renderer()
)

# ---- save main outputs ------------------------------------------------------

dir.create("output", recursive = TRUE, showWarnings = FALSE)

run_id <- str_glue(
  "penguins_{main_fit$n_shapes}_{shape_type}_seed-{main_seed}"
)

ggsave(
  str_glue("output/{run_id}.png"),
  final_plot,
  width = 12,
  height = 12 * context$h / context$w,
  dpi = 200,
  bg = "white"
)
ggsave(
  str_glue("output/{run_id}.pdf"),
  final_plot,
  width = 12,
  height = 12 * context$h / context$w,
  bg = "white"
)
ggsave(
  str_glue("output/{run_id}_progress.png"),
  progress_plot,
  width = 12,
  height = 12 * context$h / context$w * 1.6,
  dpi = 150,
  bg = "white"
)
ggsave(
  str_glue("output/{run_id}_error.png"),
  error_plot,
  width = 8,
  height = 5,
  dpi = 150,
  bg = "white"
)
write_csv(shape_tbl, str_glue("output/{run_id}_shapes.csv"))
anim_save(str_glue("output/{run_id}_build-up.gif"), build_up_gif)

run_metadata <- tibble(
  run_id = run_id,
  source_url = image_url,
  source_md5 = image_md5,
  seed = main_seed,
  shape_type = shape_type,
  shapes_requested = n_shapes,
  shapes_accepted = main_fit$n_shapes,
  alpha = shape_alpha,
  work_width = work_width,
  work_height = context$h,
  candidates_per_batch = n_candidates,
  max_age = max_age,
  ellipse_vertices = ellipse_vertices,
  initial_rmse = first(history$rmse),
  final_rmse = main_fit$final_rmse
)
write_csv(run_metadata, str_glue("output/{run_id}_metadata.csv"))

# ---- optional: animate completed fits from several seeds -------------------

if (make_seed_variation_gif) {
  message(
    "Building ",
    length(variation_seeds),
    " completed reconstructions for the multi-seed GIF."
  )

  variation_tables <- map(
    variation_seeds,
    \(seed_value) {
      if (seed_value == main_seed) {
        # Reuse the first part of the main fit instead of recomputing it.
        filter(shape_tbl, id <= variation_n_shapes)
      } else {
        fit_primitive(
          seed_value = seed_value,
          n_shapes_to_add = variation_n_shapes,
          context = context,
          show_progress = TRUE
        )$shape_tbl
      }
    }
  ) |>
    list_rbind()

  seed_levels <- str_glue("Seed {variation_seeds}")
  variation_tables <- variation_tables |>
    mutate(
      seed_frame = factor(str_glue("Seed {seed}"), levels = seed_levels)
    )

  variation_plot <- variation_tables |>
    ggplot(
      aes(
        x,
        y,
        group = interaction(seed, id),
        fill = fill
      )
    ) +
    geom_polygon(alpha = context$shape_alpha, colour = NA) +
    scale_fill_identity() +
    coord_fixed(
      xlim = c(0.5, context$w + 0.5),
      ylim = c(0.5, context$h + 0.5),
      expand = FALSE
    ) +
    labs(
      title = "{current_frame}",
      subtitle = str_glue(
        "{variation_n_shapes} {shape_label}; same target and settings"
      )
    ) +
    theme_void() +
    theme(
      panel.background = element_rect(
        fill = rgb(
          context$background_rgb[1],
          context$background_rgb[2],
          context$background_rgb[3]
        ),
        colour = NA
      ),
      plot.background = element_rect(fill = "white", colour = NA),
      plot.title = element_text(size = 18, margin = margin(6, 0, 2, 0)),
      plot.subtitle = element_text(size = 11, colour = "grey40")
    ) +
    transition_manual(seed_frame)

  variation_end_pause <- 1
  variation_gif <- animate(
    variation_plot,
    nframes = length(variation_seeds) + variation_end_pause,
    fps = 1,
    end_pause = variation_end_pause,
    width = 1200,
    height = round(1200 * context$h / context$w) + 80,
    renderer = gifski_renderer(loop = TRUE)
  )

  variation_id <- str_glue(
    "penguins_seed-variation_{variation_n_shapes}_{shape_type}"
  )
  write_csv(
    variation_tables,
    str_glue("output/{variation_id}_shapes.csv")
  )
  anim_save(str_glue("output/{variation_id}.gif"), variation_gif)
}

message(
  "Finished. Main outputs use the run ID '",
  run_id,
  "' in the output directory."
)
