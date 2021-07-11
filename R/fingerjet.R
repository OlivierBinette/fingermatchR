#' FingerJet Minutiae Extractor
#' 
#' 
#' @export
fj_minutiae <- function(imgfiles, outputdir = ".", silent = FALSE, options = "", mc.cores = 1) {
  
  if (!dir.exists(outputdir)) dir.create(outputdir)
  imgnames <- basename(tools::file_path_sans_ext(imgfiles))
  n <- length(imgfiles)
  
  if (!silent) {
    cat(crayon::green("Running FingerJet minutiae extrator on", length(imgfiles), "image files.\n"))
  }
  
  tmp = tempfile()
  lapply(1:n, function(i) {
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
  })
  
  suppressWarnings(file.remove(tmp))
  
  return(tibble(imgfile = imgfiles, out = file.path(outputdir, paste0(imgnames))))
}
