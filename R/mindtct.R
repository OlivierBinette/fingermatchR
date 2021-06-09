#' Minutia Detection
#'
#' Detect minutiae in fingerprint images using NIST's MINDTCT program.
#'
#' @note The `mindtct` program, part of NIST Biometric Image Software (NBIS), should be installed and available in PATH. If not in PATH, the path to NBIS executables should be specified as a global option through `options(NBIS_bin = <path_to_binaries>)`.
#'
#' @usage mindtct(imgfiles, outputdir = ".", silent = FALSE, options = "", mc.cores = parallel::detectCores())
#'
#' @param imgfiles list or character vector of paths to image files compatible with `mindtct`.
#' @param outputdir directory where mindtct output is saved. For each image, a directory named after the image is created within the output directory. Ouput files of `mindtct` are saved as `out.*` in their corresponding directory.
#' @param silent whether or not to hide messages. Default is FALSE.
#' @param options flags and options to pass to the `mindtct` program.
#' @param mc.cores Optional number of cores accross which to parallelize execution. Default is 1 (no parallelization).
#'
#' @returns tibble with one row for each processed image. The column "imagefile" contains the path to the original image file. The column "out" contains the directory path to `mindtct` output.
#'
#' @import parallel here
#' @export
mindtct <- function(imgfiles, outputdir = ".", silent = FALSE, options = "", mc.cores = 1) {
  if (!dir.exists(outputdir)) dir.create(outputdir)
  imgnames <- basename(tools::file_path_sans_ext(imgfiles))
  n <- length(imgfiles)

  ncores <- min(n, parallel::detectCores())

  if (!silent) {
    cat(crayon::green("Running mindtct on", length(imgfiles), "image files.\n"))
  }

  executable <- if (!is.null(getOption("NBIS_bin"))) file.path(getOption("NBIS_bin"), "mindtct") else "mindtct"
  parallel::mclapply(1:n, function(i) {
    if (!dir.exists(file.path(outputdir, imgnames[[i]]))) dir.create(file.path(outputdir, imgnames[[i]]))
    system2(executable,
      args = c(
        normalizePath(imgfiles[[i]]),
        file.path(outputdir, imgnames[[i]], "out"),
        options
      )
    )
  }, mc.cores = mc.cores, mc.preschedule = FALSE)

  return(tibble(imgfile = imgfiles, out = file.path(outputdir, paste0(imgnames))))
}

#' Extract minutiae information from `mindtct` output
#'
#' Construct a tibble containing minutiae coordinates, orientation, and quality.
#'
#' @usage function(mindtct_out)
#'
#' @param mindtct_out output from the `mindtct()` function. This should be a tibble with one row for each processed image. The column "imgfile" should contain the path to the original image. The column "out" should contain the path to the corresponding `mindtct` output directory.
#'
#' @import tidyr dplyr
#' @importFrom vroom vroom
#'
#' @export
tidyMinutiae <- function(mindtct_out) {
  minutiae <- lapply(mindtct_out$out, function(path) {
    suppressMessages(vroom(file.path(path, "out.xyt"), col_names = c("x", "y", "theta", "quality")))
  })

  bind_cols(tibble(minutiae), mindtct_out) %>%
    tidyr::unnest(minutiae)
}

#' Plot detected minutiae
#' 
#' Plot fingerprint image, its binarization, and detected minutiae with orientaiton and quality indicator.
#' 
#' @usage plotMinutiae(mindtct_out, maxPlots = 5, col = 3, lwd = 1.5)
#' 
#' @param mindtct_out output from the `mindtct()` function. This should be a tibble with one row for each processed image. The column "imgfile" should contain the path to the original image. The column "out" should contain the path to the corresponding `mindtct` output directory.
#' @param maxPlots maximal number of fingerprint images to show (number of rows in the grid plot.)
#' 
#' 
#' @import dplyr
#' @importFrom imager load.image
#' @importFrom hexView readRaw
#' @export
plotMinutiae <- function(mindtct_out, maxPlots = 5, col = 3, lwd = 1.5) {
  k <- min(maxPlots, nrow(mindtct_out))
  par(mar = c(0, 0, 0, 0), mfrow = c(k, 3))
  for (i in 1:k) {
    img <- imager::load.image(mindtct_out$imgfile[[i]])
    binaryImage <- hexView::readRaw(file.path(mindtct_out$out[[i]], "out.brw"))

    image_matrix <- matrix(binaryImage$fileRaw, nrow = ncol(img), ncol = nrow(img), byrow = TRUE)

    plot(img, axes = FALSE)
    plot(as.raster(image_matrix))
    minutiae <- tidyMinutiae(mindtct_out[i, ])

    colRamp <- rev(colorRamps::matlab.like(diff(range(minutiae$quality)) + 1))
    cols <- colRamp[minutiae$quality - min(minutiae$quality) + 1]

    x <- minutiae$x
    y <- minutiae$y
    points(x, y, col = cols, lwd = lwd)

    # Plot orientation
    u <- cos(minutiae$theta)
    v <- sin(minutiae$theta)

    segments(x, y, x + 10 * u, y + 10 * v, col = cols, lwd = lwd)

    plot.new()
    legend_image <- as.raster(matrix(rev(colRamp), ncol = 1))
    text(x = 0.5, y = seq(0.2, 0.8, l = 5), labels = seq(0, 1, l = 5), pos = 4)
    rasterImage(legend_image, 0.4, 0.2, 0.5, 0.8)
    title("Quality", line = -2, )
  }
}
