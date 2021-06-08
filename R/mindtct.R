#' @import parallel here
#' @export
mindtct <- function(imgfiles, outputdir = ".", silent = FALSE, options = "") {
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
  }, mc.cores = parallel::detectCores(), mc.preschedule = FALSE)

  return(file.path(outputdir, paste0(imgnames)))
}

#' @import vroom tibble tidyr dplyr
#' @export
tidyMinutiae <- function(mindtct_out) {
  minutiae = lapply(mindtct_out, function(path) {
    suppressMessages(vroom(file.path(path, "out.xyt"), col_names = FALSE))
  })
  names(minutiae) = mindtct_out
  df = bind_rows(minutiae, .id="source")
  colnames(df) = c("source", "x", "y", "theta", "quality")

  return(df)
}

#' @import hexView imager dplyr
#' @export
plotMinutiae <- function(source) {
  source = tools::file_path_sans_ext(source)
  img <- imager::load.image(paste0(source, ".png"))
  binaryImage <- hexView::readRaw(file.path(source, "out.brw"))

  image_matrix <- matrix(binaryImage$fileRaw, nrow=ncol(img), ncol=nrow(img), byrow =TRUE)

  par(mar=c(0,0,0,0), mfrow=c(1,2))
  plot(img, axes=FALSE)
  plot(as.raster(image_matrix))
  minutiae = tidyMinutiae(source)
  points(minutiae$x, minutiae$y, col=2)
}

