# R code review: `primitive_penguins.R`

Reviewed file: `assets/code/primitive_penguins.R`  
Review date: 2026-10-12  
Source edits made: none

## Summary

The default script is coherent, well organized, and substantially better
annotated than a typical creative-coding script. Its pixel indexing is
internally consistent, the closed-form color calculation is correct, and a
reduced end-to-end run produced the PNG, CSV, and GIF outputs successfully.

The review found no Critical or High issues. It found six Medium issues and
five Low issues. The two most important correctness findings are that an empty
batch of proposals can crash `best_shape()`, and that the main loop can accept
a shape that increases error. Neither appeared in the reduced normal run, but
both are reproducible with supported parameter combinations or valid internal
states.

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 0 |
| Medium | 6 |
| Low | 5 |

The repository does not contain `.claude/rules/r-code-conventions.md`, so this
review used current R, tidyverse, reproducibility, and teaching-code standards.

## Top three findings

1. An all-empty initial proposal batch leaves `best$shape` undefined and
   crashes the hill climber.
2. The main loop always paints the best proposal, even when no proposal lowers
   SSE, so RMSE is not guaranteed to be monotone.
3. Ellipses are optimized as 24-sided polygons but exported and drawn as
   60-sided polygons, so the plotted result does not exactly match the geometry
   that was scored.

## Validation performed

- Parsed the complete script under R 4.6.1.
- Confirmed the required packages are installed in the review environment:
  `tidyverse`, `png`, `progress`, `gganimate`, and `gifski`.
- Ran an isolated reduced workflow with 8 mixed shapes, a working width of 60,
  4 candidates, and a maximum age of 5. The run completed and wrote both PNGs,
  the polygon CSV, and the GIF.
- Confirmed all coordinates and RMSE values in that run were finite and that
  its observed RMSE was monotone.
- Exercised triangle, ellipse, rectangle, and mixed shape paths.
- Verified the full prior 1,000-triangle CSV contains 1,000 shape IDs, 3,000
  finite vertices, and IDs from 1 through 1,000.
- Confirmed the reviewed website copy and the original project copy are
  byte-identical (SHA-1
  `e59f40c1b40f23196030d26e8fbdbfb15d6f8fdb`).
- Confirmed the current source image is RGBA, 1,800 by 1,074 pixels, and its
  SHA-256 is
  `09b8d656b7e432aff84e961af5a3bbb46cf0291ee08f43dd42224dcf2abb7245`.
- Confirmed the remote image URL currently resolves.
- Ran `lintr`; it reported formatting and script-context object-usage notices,
  but no additional runtime defect. Most object-usage notices are expected
  because this is a sourced script that attaches tidyverse packages rather than
  a package namespace.

The full 1,000-shape search was not rerun during this review. The reduced run,
the existing full artifacts, and focused reproductions cover the relevant
execution paths without repeating the expensive artistic search.

## Medium findings

### M1. Empty proposals can crash `best_shape()`

**Lines:** 164-166, 177-192  
**Impact:** A legitimate low-candidate run can fail rather than retrying.

`evaluate()` returns only `list(sse = Inf)` when a polygon contains no working
pixel centers. If every initial proposal is empty, `reduce()` still returns one
of those abbreviated lists. `best$shape` is then `NULL`, and line 184 passes it
to `mutate_shape()`.

This was reproduced with the current image in triangle mode using
`n_candidates <- 1` and `set.seed(319)`:

```text
argument is of length zero
```

Recommended correction:

- Return a structurally complete result from `evaluate()`, even for an empty
  mask; and
- make `best_shape()` filter to finite, nonempty proposals and retry or stop
  with an explicit message when none remain.

For a teaching script, an explicit error such as "No candidate covered a
working pixel; increase n_candidates or retry" is much easier to diagnose than
the current downstream error.

### M2. A shape can be painted even when it increases error

**Lines:** 177-192, 209-215  
**Impact:** The implementation does not guarantee the stated rule that each
accepted shape lowers error.

`best_shape()` chooses the least-bad proposal in its batch, but it never
compares that proposal with the unchanged canvas. The run loop then paints the
proposal unconditionally. Late in a search, or with small `n_candidates` and
`max_age`, every proposed constant-color translucent shape can be worse than
doing nothing.

This was reproduced with a synthetic canvas already equal to its target,
`n_candidates = 1`, and `max_age = 0`: the starting SSE was zero and every
painted shape increased it.

Recommended correction:

- Treat the unchanged canvas as a no-op candidate; or
- require `is.finite(best$sse) && best$sse < sse` before updating `current`.

If no candidate improves the canvas, retry with a bounded number of batches or
terminate early with a clear message. Add an invariant check or test that
`diff(history$rmse) <= 0` within numerical tolerance.

### M3. Ellipse geometry differs between optimization and output

**Lines:** 118-129, 164-165, 220-225  
**Impact:** Ellipse and mixed-mode plots do not exactly represent the geometry
used to compute their colors or RMSE history.

During scoring, `shape_polygon()` uses its default of 24 vertices. When shapes
are converted to `shape_tbl`, ellipses are regenerated with 60 vertices. In a
100-ellipse comparison at the default working resolution, 45 ellipses had
different 24- and 60-vertex pixel masks; the largest symmetric difference was
53 pixels.

Recommended correction: define one documented `ellipse_vertices` parameter and
use it for both evaluation and export. If the deliberate goal is to optimize a
coarse approximation and draw a smoother one, state that tradeoff and note that
the displayed image will not correspond exactly to `history`.

### M4. Advertised parameters and image structure are not validated

**Lines:** 28-37, 46-58, 86-100, 164-180  
**Impact:** Common parameter mistakes fail later with indirect errors or
non-finite values.

Examples include:

- `shape_alpha <- 0`, which makes the color calculation divide by zero;
- `n_candidates <- 0`, which gives `reduce()` an empty input;
- an unsupported `shape_type`, which makes `switch()` return `NULL`;
- a nonpositive or nonfinite `work_width`; and
- a three-channel RGB PNG, because the loading code requires `img[, , 4]`.

Recommended correction: add a short validation block immediately after the
parameters and another after `readPNG()`:

- use `match.arg()` for `shape_type`;
- require positive whole numbers for counts and dimensions;
- require `0 < shape_alpha && shape_alpha <= 1`;
- validate `bg_fill` with a clear error; and
- require three or four numeric image channels, adding an all-ones alpha
  channel when an RGB image is intentionally supported.

These checks also serve as useful documentation for readers who want to change
the experiment.

### M5. The input is not fully reproducible despite `set.seed()`

**Lines:** 24, 28-44  
**Impact:** Two readers can use different image bytes with the same seed and
settings.

The source URL follows the mutable `main` branch. Once a local file exists, the
script silently reuses it without checking its provenance or integrity. Thus a
future upstream change, an old local copy, or a partial download can change the
result while the random seed remains the same.

Recommended correction: vendor the exact source image with appropriate credit,
or pin an immutable commit URL and verify a documented SHA-256 checksum before
the search. Download to a temporary file first and rename only after the image
passes validation.

### M6. The standalone script needs a clearer prerequisite and runtime contract

**Lines:** 17-37, 206-215, 264-317  
**Impact:** A reader can encounter version errors or start an expensive run
without knowing how long it will take or what will be written.

The source names only the two packages attached at the top. It later requires
`progress`, `gganimate`, and `gifski`. It also relies on features with minimum
versions:

- R 4.1 or newer for `|>` and `\()`;
- dplyr 1.1.0 or newer for per-operation `.by`; and
- purrr 1.0.0 or newer for `list_rbind()`.

The blog post supplies installation commands, but the downloadable script does
not carry that guidance with it. It also does not warn that the default search
is computationally expensive or give a first-run configuration.

Recommended annotation additions:

- a prerequisites block naming all five packages and minimum R/tidyverse
  requirements;
- a note that paths are relative to the current working directory;
- approximate runtime and output size for the default settings;
- a quick smoke-test profile, such as 10-25 shapes with lower `work_width`,
  `n_candidates`, and `max_age`;
- a one-line description of each generated file; and
- a note that `set.seed()` must be rerun before the search if a reader explores
  random-shape functions interactively.

## Low findings

### L1. "Resolution-free" overstates the saved outputs

**Lines:** 14-15, 309-317

The retained geometry is vector-based, but the script saves the plotted images
only as PNG and GIF. Either save an SVG or PDF as well, or describe the result
as "vector polygon data that can be rendered at any chosen resolution."

### L2. Core functions rely heavily on undeclared global state

**Lines:** 84-195

`random_shape()`, `mutate_shape()`, `rasterize()`, `evaluate()`, and
`best_shape()` implicitly consume combinations of `w`, `h`, `target`,
`shape_alpha`, `shape_type`, `jitter_sd`, `n_candidates`, and `max_age`.

For a teaching script, either pass the important inputs explicitly or add a
short comment above each function listing the shared state it uses. Explicit
arguments would also make focused tests much easier.

### L3. Output names omit provenance and files are overwritten silently

**Lines:** 311-317

The filenames include only shape count and type. Runs with a different seed,
alpha, working width, source image, or search effort overwrite the same files.
The CSV also lacks the background color, alpha, canvas dimensions, seed, and
target checksum needed to reconstruct the image on its own.

Add a compact run ID or metadata sidecar, and document the overwrite behavior.

### L4. Animation timing is adjusted rather than honoring the requested FPS

**Lines:** 272, 302-306

In the current review environment, `animate()` reports:

```text
`nframes` and `fps` adjusted to match transition
```

The existing full GIF has 66 frames; most have a 0.10-second delay even though
the call requests 12 FPS. The visual result is valid, but the timing is partly
implicit. Specify `nframes` or `duration` consistently with the number of manual
states, then verify the final pause and frame count.

### L5. Raster bounding sequences are formed before their bounds are validated

**Lines:** 138-143

The `:` operator always returns a sequence, including when the left endpoint is
greater than the right endpoint. Therefore `length(xs) == 0` and
`length(ys) == 0` cannot detect an empty integer bounding range. Fully
off-canvas polygons are caught by the other conditions, and the point-in-polygon
test filters most reversed-range cases, so this did not break the reviewed run.
It is nevertheless misleading and can create unnecessary candidate pixels.

Compute and compare scalar lower and upper bounds first; return early when
`x_min > x_max` or `y_min > y_max`; then call `seq.int()`.

## Annotation assessment

The existing comments already explain the overall algorithm, downsampling,
column-major pixel indexing, the alpha/color equation, hill climbing, coordinate
orientation, faceting, and animation intent. Those are the hardest conceptual
parts, and they are handled well.

To make the file genuinely follow-along-ready, the next annotation pass should
focus on operational context rather than adding comments to every line:

1. prerequisites and compatible versions;
2. valid parameter ranges and speed/quality tradeoffs;
3. a small first run before the 1,000-shape run;
4. shared-state dependencies of each function;
5. what each output contains and whether it will be overwritten; and
6. short checks readers can use to confirm that RMSE is finite and nonincreasing.

## Suggested test cases after fixes

1. Parse and run a 10-shape triangle smoke test from an empty temporary folder.
2. Repeat for ellipse, rectangle, and mixed modes.
3. Verify that RGB and RGBA inputs either both work or fail with the documented
   message.
4. Verify rejected values: zero alpha, zero candidates, zero shapes, invalid
   shape type, and nonpositive width.
5. Force every initial candidate to be empty and confirm bounded retry or a
   clear error.
6. Use a canvas equal to its target and confirm the algorithm performs a no-op
   rather than increasing SSE.
7. Assert that RMSE is finite and nonincreasing after every accepted shape.
8. Assert that scored and exported ellipse masks use the same vertex count.
9. Run twice with the same input checksum, package environment, seed, and
   parameters; compare the shape CSV hashes.
10. Verify GIF frame count, timing, final pause, dimensions, and output paths.

## Overall assessment

The script is suitable as the basis for the post, and the default triangle
workflow has already produced valid full-scale artifacts. Before presenting it
as instructional code, fix M1-M4 so the implementation matches its stated
algorithm under supported settings. Then add the prerequisite, runtime, and
output annotations in M5-M6 and L3. The remaining Low items are worthwhile
polish rather than publication blockers.
