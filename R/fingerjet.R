#' FingerJet Minutiae Extractor
#' 
#' 
#' @export
fj_minutiae <- function(imgfiles, outputdir = ".", options = "", mc.cores = 1) {
  
  if (!dir.exists(outputdir)) dir.create(outputdir)
  imgnames <- basename(tools::file_path_sans_ext(imgfiles))
  n <- length(imgfiles)
  
  cli::cli_alert_info("Running FingerJet minutiae extractor on {n} image files...")
  cli::cli_progress_bar("", total=n)
  
  tmp = tempfile()
  for(i in 1:n) {
    if (!dir.exists(file.path(outputdir, imgnames[[i]]))) dir.create(file.path(outputdir, imgnames[[i]]))
    
    png <- png::readPNG(imgfiles[[i]])
    con <- file(tmp, open = "wb")
    
    # PGM file metadata
    writeChar(paste("P", 5, "\n", sep = ""), con = con, eos = NULL)
    writeChar(paste(nrow(png), " ", ncol(png), "\n", sep = ""), con = con, eos = NULL)
    writeChar(paste(255, "\n", sep = ""), con = con, eos = NULL)
    
    # Write image file
    writeBin(as.integer(png*255), con, size = 1)
    close(con)
    
    FJFX_extract_minutiae_from_PGM(tmp, file.path(outputdir, imgnames[[i]], "out.ist"))
    
    istfile = file.path(outputdir, imgnames[[i]], "out.ist")
    xytfile = file.path(outputdir, imgnames[[i]], "out.xyt")
    if (file.exists(xytfile)) file.remove(xytfile)
    if (!file.exists(istfile)) {
      cli::cli_alert_warning(paste0("FingerJet minutiae extraction for ", imgfiles[[i]], " failed."))
    } else {
      tryCatch(
        fmr_to_xyt(file.path(outputdir, imgnames[[i]], "out.ist"), "ISO_2005", file.path(outputdir, imgnames[[i]], "out.xyt")),
        error = function (e) {
          cli::cli_alert_danger(paste0("Error exporting ", file.path(outputdir, imgnames[[i]], "out.ist"), " to .xyt file."))
          stop(e)
        }
      )
    }
    
    cli::cli_progress_update()
  }
  
  cli::cli_alert_success("done running FingerJet.")
  
  suppressWarnings(file.remove(tmp))
  
  return(tibble(imgfile = imgfiles, out = file.path(outputdir, paste0(imgnames))))
}
