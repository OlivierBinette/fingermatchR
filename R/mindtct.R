#' @import parallel here
#' @export
mindtct <- function(imgfiles, outputdir = ".", silent = FALSE, options = "", mc.cores = parallel::detectCores()) {
  if (!dir.exists(outputdir)) dir.create(outputdir)
  imgnames = basename(tools::file_path_sans_ext(imgfiles))
  n = length(imgfiles)

  ncores = min(n, parallel::detectCores())

  if (!silent) {
    cat(crayon::green("Running mindtct on", length(imgfiles), "image files.\n"))
  }

  executable = if (!is.null(getOption("NBIS_bin"))) file.path(getOption("NBIS_bin"), "mindtct") else "mindtct"
  parallel::mclapply(1:n, function(i) {
    if (!dir.exists(file.path(outputdir, imgnames[[i]]))) dir.create(file.path(outputdir, imgnames[[i]]))
    system2(executable,
            args=c(normalizePath(imgfiles[[i]]),
                   file.path(outputdir, imgnames[[i]], "out"),
                   options))
  }, mc.cores = mc.cores, mc.preschedule = FALSE)

  return(tibble(imgfile = imgfiles, out = file.path(outputdir, paste0(imgnames))))
}

#' @import tidyr dplyr
#' @importFrom vroom vroom
#'
#' @export
tidyMinutiae <- function(mindtct_out) {
  minutiae = lapply(mindtct_out$out, function(path) {
    suppressMessages(vroom(file.path(path, "out.xyt"), col_names = c("x", "y", "theta", "quality")))
  })

  bind_cols(tibble(minutiae), mindtct_out) %>%
    tidyr::unnest(minutiae)
}

#' @import dplyr
#' @importFrom imager load.image
#' @importFrom hexView readRaw
#' @export
plotMinutiae <- function(mindtct_out, maxPlots = 5, col=3, lwd=1.5) {
  k = min(maxPlots, nrow(mindtct_out))
  par(mar=c(0,0,0,0), mfrow=c(k,3))
  for (i in 1:k) {
    img <- imager::load.image(mindtct_out$imgfile[[i]])
    binaryImage <- hexView::readRaw(file.path(mindtct_out$out[[i]], "out.brw"))

    image_matrix <- matrix(binaryImage$fileRaw, nrow=ncol(img), ncol=nrow(img), byrow =TRUE)

    plot(img, axes=FALSE)
    plot(as.raster(image_matrix))
    minutiae = tidyMinutiae(mindtct_out[i,])

    colRamp = rev(colorRamps::matlab.like(diff(range(minutiae$quality)) + 1))
    cols = colRamp[minutiae$quality - min(minutiae$quality) + 1]

    x = minutiae$x
    y = minutiae$y
    points(x, y, col=cols, lwd=lwd)

    # Plot orientation
    u = cos(minutiae$theta)
    v = sin(minutiae$theta)

    segments(x, y, x+10*u, y+10*v, col=cols, lwd=lwd)

    plot.new()
    legend_image <- as.raster(matrix(rev(colRamp), ncol=1))
    text(x=0.5, y = seq(0.2, 0.8,l=5), labels = seq(0,1,l=5), pos=4)
    rasterImage(legend_image, 0.4, 0.2, 0.5, 0.8)
    title("Quality", line = -2, )

  }

}

