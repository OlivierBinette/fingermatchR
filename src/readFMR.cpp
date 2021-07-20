#include <Rcpp.h>
using namespace Rcpp;

#include <sys/stat.h>
#include <sys/types.h>
#include <sys/queue.h>

#include <fcntl.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "biomdimacro.h"
//#include "biomdi.h"
#include "biomdi.c"
//#include "fmr.h"
// Strange linker issue when only using the "fmr.h" header... this is a temporary bypass.
#include "libfmr/fmr.c"
#include "libfmr/fvmr.c"
#include "libfmr/fmd.c"
#include "libfmr/fedb.c"
#include "libfmr/validate.c"

// Convert string type description to code specified in fmr.h
static int stdstr_to_type(std::string &stdstr) {
  const char *str = stdstr.c_str();
  
  if (strcmp(str, "ANSI_2004") == 0)
    return (FMR_STD_ANSI);
  if (strcmp(str, "ISO_2005") == 0)
    return (FMR_STD_ISO);
  if (strcmp(str, "ISONC_2005") == 0)
    return (FMR_STD_ISO_NORMAL_CARD);
  if (strcmp(str, "ISOCC_2005") == 0)
    return (FMR_STD_ISO_COMPACT_CARD);
  if (strcmp(str, "ANSI_2007") == 0)
    return (FMR_STD_ANSI07);
  return (-1);
}


//' Print fingerprint minutiae record
//'
//' Print fingerprint minutiae record as specified in ANSI/INCITS 378-2004 and
//' ISO/IEC 19794-2:2005. Note that ANSI/INCITS 378-2004 and ISO/IEC 19794-2:2005
//' are older standards which may not be compatible with recent corrections.
//'
//' @usage printFMR(filepath, type)
//'
//' @param filepath character path to file containing the fingerprint minutiae
//' record (e.g. a "*.ist" file).
//' @param type character description of the record standard; one of the following:
//' - "ANSI_2004": ANSI/INCITS 378-2004 format
//' - "ANSI_2007": ANSI/INCITS 378-2007 format
//' - "ISO_2005": ISO/IEC 19794-2:2005 format
//' - "ISONC_2005": ISO/IEC 19794-2:2005 normal card format
//' - "ISOCC_2005": ISO/IEC 19794-2:2005 compact card format
//'
//' @note This R package is based on [NIST's BiomDI software](https://www.nist.gov/services-resources/software/biomdi-software-tools-supporting-standard-biometric-data-interchange) and includes the
//' libfmr C library. This function is adapted from the prfmr program.
//'
//' @export
// [[Rcpp::export]]
void print_fmr(std::string filepath, std::string type) {
  int in_type = stdstr_to_type(type);
  
  FILE *fp;
  struct stat sb;
  struct finger_minutiae_record *fmr;
  int ret;
  
  fp = fopen(filepath.c_str(), "rb");
  if (fp == NULL) {
    stop("open of file failed.\n");
  }
  
  if (stat(filepath.c_str(), &sb) < 0) {
    stop("Could not get stats on input file.\n");
  }
  
  if (new_fmr(in_type, &fmr) < 0) {
    stop("could not allocate FMR\n");
  }
  
  ret = read_fmr(fp, fmr);
  if (ret != READ_OK) {
    stop("Could not read fingerprint minutiae record");
  }
  if (validate_fmr(fmr) != VALIDATE_OK) {
    stop("Finger Minutiae Record is invalid.");
  }
  
  print_fmr(stdout, fmr);
  fclose(fp);
}

std::string rcpp_fmd_type_string(FMD *fmd)
{
  switch (fmd->type) {
  case FMD_MINUTIA_TYPE_OTHER:
    return ("Other");
  case FMD_MINUTIA_TYPE_RIDGE_ENDING:
    return ("Ridge Ending");
  case FMD_MINUTIA_TYPE_BIFURCATION:
    return ("Bifurcation");
  default:
    return ("Unknown");
  }
}

List rcpp_read_fmd(struct finger_minutiae_data *fmd) {
  return List::create(Named("x_coord") = fmd->x_coord,
                      Named("y_coord") = fmd->y_coord,
                      Named("angle") = fmd->angle,
                      Named("converted_angle") = fmd_convert_angle(fmd),
                      Named("quality") = fmd->quality,
                      Named("type") = rcpp_fmd_type_string(fmd));
}

List rcpp_read_fvmr(struct finger_view_minutiae_record *fvmr) {
  
  std::list<List> rcpp_minutiae_data;
  struct finger_minutiae_data *fmd;
  TAILQ_FOREACH(fmd, &fvmr->minutiae_data, list) {
    rcpp_minutiae_data.push_back(rcpp_read_fmd(fmd));
  }
  
  return List::create(Named("finger_number") = fvmr->finger_number,
                      Named("view_number") = fvmr->view_number,
                      Named("impression_type") = fvmr->impression_type,
                      Named("finger_quality") = fvmr->finger_quality,
                      Named("format_std") = fvmr->format_std,
                      Named("algorithm_id") = fvmr->algorithm_id,
                      Named("x_image_size") = fvmr->x_image_size,
                      Named("y_image_size") = fvmr->y_image_size,
                      Named("x_resolution") = fvmr->x_resolution,
                      Named("y_resolution") = fvmr->y_resolution,
                      Named("number_of_minutiae") = fvmr->number_of_minutiae,
                      Named("minutiae_data") = rcpp_minutiae_data);
}


//' Read fingerprint minutiae records
//'
//' Read fingerprint minutiae records as specified in ANSI/INCITS 378-2004 and
//' ISO/IEC 19794-2:2005. The record is returned as a nested list structured as described
//' in the details section. Note that ANSI/INCITS 378-2004 and ISO/IEC 19794-2:2005
//' are older standards which may not be compatible with recent corrections.
//'
//' @usage readFMR(filepath, type)
//'
//' @param filepath character path to file containing the fingerprint minutiae
//' record (e.g. a "*.ist" file).
//' @param type character description of the record standard; one of the following:
//' - "ANSI_2004": ANSI/INCITS 378-2004 format
//' - "ANSI_2007": ANSI/INCITS 378-2007 format
//' - "ISO_2005": ISO/IEC 19794-2:2005 format
//' - "ISONC_2005": ISO/IEC 19794-2:2005 normal card format
//' - "ISOCC_2005": ISO/IEC 19794-2:2005 compact card format
//'
//' @return raw fingerprint minutiae record as a nested list with the following elements (raw, integer or string types):
//' - format_std
//' - product_identifier_owner
//' - product_identifier_type
//' - scanner_id
//' - compliance
//' - x_image_size
//' - y_image_size
//' - x_resolution
//' - y_resolution
//' - num_views
//' - finger_views: list of fingerprint views each structured as follows:
//'     - format_std
//'     - finger_number
//'     - view_number
//'     - impression_type
//'     - finger_quality
//'     - number_of_minutiae
//'     - x_image_size
//'     - y_image_size
//'     - x_resolution
//'     - y_resolution
//'     - algorithm_id
//'     - minutiae_data: list of minutiae data records each structured as follows:
//'         - format_std
//'         - index
//'         - type
//'         - x_coord
//'         - y_coord
//'         - angle
//'         - quality
//'
//' @note This R package is based on [NIST's BiomDI software](https://www.nist.gov/services-resources/software/biomdi-software-tools-supporting-standard-biometric-data-interchange) and includes the
//' libfmr C library. This function is adapted from the prfmr program.
//' 
//' @note The nested list contains elements of raw type. Make sure to use `as.integer()` in order to convert to integer values. 
//' 
//' @export
// [[Rcpp::export]]
Rcpp::List read_fmr_raw(std::string filepath, std::string type) {
  int in_type = stdstr_to_type(type);
  
  FILE *fp;
  struct stat sb;
  struct finger_minutiae_record *fmr;
  int ret;
  
  fp = fopen(filepath.c_str(), "rb");
  if (fp == NULL) {
    stop("open of file failed.\n");
  }
  
  if (new_fmr(in_type, &fmr) < 0) {
    stop("could not allocate FMR\n");
  }
  
  ret = read_fmr(fp, fmr);
  if (ret != READ_OK) {
    stop("Could not read fingerprint minutiae record");
  }
  if (validate_fmr(fmr) != VALIDATE_OK) {
    stop("Finger Minutiae Record is invalid.");
  }
  
  std::list<List> rcpp_finger_views;
  struct finger_view_minutiae_record *fvmr;
  int i = 1;
  TAILQ_FOREACH(fvmr, &fmr->finger_views, list) {
    rcpp_finger_views.push_back(rcpp_read_fvmr(fvmr));
  }
  
  List rcpp_fmr = List::create(Named("format_std") = fmr->format_std,
                               Named("format_id") = fmr->format_id,
                               Named("spec_version") = fmr->spec_version,
                               Named("record_length") = fmr->record_length,
                               Named("record_length_type") = fmr->record_length_type,
                               Named("product_identifier_owner") = fmr->product_identifier_owner,
                               Named("product_identifier_type") = fmr->product_identifier_type,
                               Named("scanner_id") = fmr->scanner_id,
                               Named("compliance") = fmr->compliance,
                               Named("x_image_size") = fmr->x_image_size,
                               Named("y_image_size") = fmr->y_image_size,
                               Named("x_resolution") = fmr->x_resolution,
                               Named("y_resolution") = fmr->y_resolution,
                               Named("num_views") = fmr->num_views,
                               Named("finger_views") = rcpp_finger_views);
  
  fclose(fp);
  return rcpp_fmr;
}

//[[Rcpp::export]]
void fmr_to_xyt(std::string filepath, std::string type, std::string outputpath) {
  int in_type = stdstr_to_type(type);
  
  FILE *fp;
  struct stat sb;
  struct finger_minutiae_record *fmr;
  int ret;
  
  fp = fopen(filepath.c_str(), "rb");
  if (fp == NULL) {
    stop("open of file failed.\n");
  }
  
  if (new_fmr(in_type, &fmr) < 0) {
    stop("could not allocate FMR\n");
  }
  
  ret = read_fmr(fp, fmr);
  if (ret != READ_OK) {
    stop("Could not read fingerprint minutiae record");
  }
  if (validate_fmr(fmr) != VALIDATE_OK) {
    stop("Finger Minutiae Record is invalid.");
  }
  
  FILE *fo;
  fo = fopen(outputpath.c_str(), "wt");
  if (fo == NULL) {
    stop("Could not open output file.");
  }
  
  struct finger_view_minutiae_record *fvmr;
  TAILQ_FOREACH(fvmr, &fmr->finger_views, list) {
    struct finger_minutiae_data *fmd;
    TAILQ_FOREACH(fmd, &fvmr->minutiae_data, list) {
      fprintf(fo, "%u %u %u %u \"%s\" \n", 
              fmd->y_coord, 
              fmd->x_coord, 
              fmd_convert_angle(fmd),
              fmd->quality,
              fmd_type_string(fmd));
    }
  }
  
  fclose(fp);
  fclose(fo);
  
  // fingermatchR:::fmr_to_xyt(file.path("data-raw/test/out.ist"), "ISO_2005", file.path("data-raw/test/out.xyt"))
}

