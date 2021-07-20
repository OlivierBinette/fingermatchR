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
#' @import parallel here cli
#' @export
mindtct <- function(imgfiles, outputdir = ".", options = "") {
  if (!dir.exists(outputdir)) dir.create(outputdir)
  imgnames <- basename(tools::file_path_sans_ext(imgfiles))
  n <- length(imgfiles)

  ncores <- min(n, parallel::detectCores())

  executable <- if (!is.null(getOption("NBIS_bin"))) file.path(getOption("NBIS_bin"), "mindtct") else "mindtct"

  cli::cli_alert_info("Running mindtct on {n} image files...")
  cli::cli_progress_bar("", total=n)
  
  for (i in 1:n) {
    if (!dir.exists(file.path(outputdir, imgnames[[i]]))) dir.create(file.path(outputdir, imgnames[[i]]))
    system2(executable,
      args = c(
        normalizePath(imgfiles[[i]]),
        file.path(outputdir, imgnames[[i]], "out"),
        options
      )
    )
    
    cli::cli_progress_update()
  }
  cli::cli_alert_success("done running mindtct.")

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
    if (file.exists(file.path(mindtct_out$out[[i]], "out.brw"))) {
      binaryImage <- hexView::readRaw(file.path(mindtct_out$out[[i]], "out.brw"))
    } else {
      binaryImage = NULL
    }
    
    if (!is.null(binaryImage)) {
      image_matrix <- matrix(binaryImage$fileRaw, nrow = ncol(img), ncol = nrow(img), byrow = TRUE)
      
      plot(img, axes = FALSE)
      plot(as.raster(image_matrix))
      minutiae <- tidyMinutiae(mindtct_out[i, ])
      
      colRamp <- rev(colorRamps::matlab.like(100))
      cols <- colRamp[minutiae$quality]
      
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
    } else {

      plot(img, axes = FALSE)
      minutiae <- tidyMinutiae(mindtct_out[i, ])
      
      colRamp <- rev(colorRamps::matlab.like(100))
      cols <- colRamp[minutiae$quality]
      
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
      plot.new()
    }
  }
}


#' Compute fingerprint matching scores
#'
#' Compute pairwise fingerprint matching scores using `bozorth3`.
#'
#' @usage matchscores(out_probes, out_gallery, outputdir = ".", options = "")
#'
#' @param out_probes tibble with a column named "out" containing paths to `mindtct` output directories.
#' @param out_gallery tibble with a column named "out" containing paths to `mindtct` output directories.
#' @param outputdir directory where scores and configuration files are saved.
#' @param options options and flags for the `bozorth3` program.
#'
#' @import tidyr
#' @export
matchscores <- function(out_probes, out_gallery, outputdir = ".", options = "") {
  FILENAME_SCORES = "bozorth3_scores"

  # Prepare probes.lis
  matesPath = file.path(outputdir, "mates.lis")
  file.create(matesPath)
  mates.lis = file(matesPath)

  probes = file.path(out_probes$out, "out.xyt")

  if (!missing(out_gallery)) {
    gallery = file.path(out_gallery$out, "out.xyt")
    writeLines(c(t(as.matrix(expand.grid(probes, gallery)))), con = mates.lis)
  } else {
    pairs = combn(1:nrow(out_probes), 2)
    writeLines(
      c(sapply(1:ncol(pairs), function(i) c(probes[pairs[1,i]], probes[pairs[2,i]]))),
      con = mates.lis)
  }
  close(mates.lis)

  executable <- if (!is.null(getOption("NBIS_bin"))) file.path(getOption("NBIS_bin"), "bozorth3") else "bozorth3"
  system2(executable,
          args = c("-A outfmt=s",
                   "-D", outputdir,
                   "-o", FILENAME_SCORES,
                   options,
                   "-M", matesPath))

  scoresFile = file(file.path(outputdir, FILENAME_SCORES))
  scores = readLines(con = scoresFile)
  close(scoresFile)

  if (!missing(out_gallery)) {
    bind_cols(score = scores,
              tidyr::crossing(probe_index = 1:nrow(out_probes),
                              gallery_index = 1:nrow(out_gallery))
    )
  } else {
    bind_cols(score=scores, probe_index = pairs[1,], gallery_index = pairs[2,])
  }
}

