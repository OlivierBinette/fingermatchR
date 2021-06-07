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

