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
