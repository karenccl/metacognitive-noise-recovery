# Shared helpers for the figure scripts: report version (default) or
# submission version (FIG_SUBMISSION=1; `make figures-submission`).
#
# The submission version follows the journal's artwork rules: no title,
# subtitle or caption inside the figure (they belong in the figure legend),
# panel letters only, code names (log_M, sigma_c) written out, TIFF (LZW) at
# 300 dpi at the final printed size (Springer: width <= 174 mm, height <= 234 mm),
# so font sizes are the printed sizes. Report PNGs are unchanged.
# Every text removed from a figure is appended to
# outputs/figures/submission/dropped_text.md, to be moved into the legend if needed.

fig_submission <- identical(Sys.getenv("FIG_SUBMISSION"), "1")
fig_sub_dir <- here::here("outputs", "figures", "submission")

# Code names -> print names, for labels and in-figure text.
print_names <- function(x) {
  if (!fig_submission || !is.character(x)) return(x)
  x <- gsub("delta_logM", "Δ log M", x, fixed = TRUE)
  x <- gsub("log_M", "log M", x, fixed = TRUE)
  x <- gsub("sigma_c", "σc", x, fixed = TRUE)
  x <- gsub(" (hmetad::epred_draws_metad)", "", x, fixed = TRUE)
  x
}

.dropped <- new.env()
.dropped$text <- character()
log_dropped <- function(what, txt) {
  if (!is.null(txt) && length(txt) && nzchar(paste(txt, collapse = "")))
    .dropped$text <- c(.dropped$text, sprintf("- %s: %s", what, gsub("\n", " ", paste(txt, collapse = " "))))
}

# One ggplot panel, made print-ready in submission mode: title, subtitle and
# caption removed (logged); a leading "A. " in the subtitle is kept as the panel
# letter; all labels pass through print_names(); fonts sized for print.
print_ready <- function(p, base_size = 8, axes = TRUE) {
  if (!fig_submission) return(p)
  l <- ggplot2::get_labs(p)
  sub <- l$subtitle
  letter <- if (!is.null(sub) && grepl("^[A-Z]\\. ", sub)) substr(sub, 1, 1) else NULL
  log_dropped("title", l$title)
  log_dropped("subtitle", if (is.null(letter)) sub else sub("^[A-Z]\\. ", "", sub))
  log_dropped("caption", l$caption)
  keep <- setdiff(names(l), c("title", "subtitle", "caption"))
  new <- lapply(l[keep], function(v) if (is.character(v)) print_names(v) else v)
  p + do.call(ggplot2::labs, c(new, list(title = NULL, subtitle = letter, caption = NULL))) +
    ggplot2::theme(text = ggplot2::element_text(size = base_size),
                   plot.subtitle = ggplot2::element_text(size = base_size + 2, face = "bold"),
                   legend.text = ggplot2::element_text(size = base_size - 1),
                   strip.text = ggplot2::element_text(size = base_size),
                   plot.margin = ggplot2::margin(4, 6, 4, 12)) +
    # axes = FALSE for schematics drawn on theme_void (keeps the axes hidden)
    (if (axes) ggplot2::theme(axis.text = ggplot2::element_text(size = base_size - 1)))
}

# Save: report PNG at `path`, or (submission) <sub_name>.tiff at the printed size.
save_fig <- function(g, path, width, height, dpi = 200, sub_name, sub_width_mm = 174, sub_height_mm) {
  if (!fig_submission) return(ggplot2::ggsave(path, g, width = width, height = height, dpi = dpi))
  stopifnot(sub_width_mm <= 174, sub_height_mm <= 234)
  dir.create(fig_sub_dir, recursive = TRUE, showWarnings = FALSE)
  out <- file.path(fig_sub_dir, paste0(sub_name, ".tiff"))
  ggplot2::ggsave(out, g, width = sub_width_mm, height = sub_height_mm, units = "mm", dpi = 300,
                  device = "tiff", compression = "lzw")
  # also a PNG preview at the same size, for checking
  ggplot2::ggsave(sub("[.]tiff$", "_preview.png", out), g, width = sub_width_mm, height = sub_height_mm,
                  units = "mm", dpi = 150)
  log_file <- file.path(fig_sub_dir, "dropped_text.md")
  writeLines(c(sprintf("## %s (%s)", sub_name, basename(path)),
               if (length(.dropped$text)) .dropped$text else "- (nothing dropped)", ""),
             con <- file(log_file, open = "a")); close(con)
  .dropped$text <- character()
  invisible(out)
}
