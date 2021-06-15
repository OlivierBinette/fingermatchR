#' Convert RGB jpg images to 8 bit grayscale png
#' 
#' @import jpeg png tools assert
#' @export
jpg_to_png <- function(input, outputdir, create.dir = FALSE, lazy = TRUE) {

  # Check if input is a directory or a list of images.
  if (dir.exists(input)) {
    imgfiles = list.files(input, pattern = "*.jpg", full.names = TRUE)
  } else {
    assert(all(file.exists(input)))
    imgfiles = input
  }

  # Check if output directory needs to be created
  if (create.dir && !dir.exists(outputdir)) dir.create(outputdir)

  # Convert images to png
  imgnames = basename(file_path_sans_ext(imgfiles))
  for (i in seq_along(imgnames)) {
    png = file.path(outputdir, paste0(imgnames[[i]], ".png"))
    if (!lazy || !file.exists(png)) {
      jpg = readJPEG(imgfiles[[i]])
      writePNG(jpg[ , ,1], target=png)
    }
  }

}
