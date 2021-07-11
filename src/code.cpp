
// [[Rcpp::plugins(cpp11)]]
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include <Rcpp.h>
#include "FRFXLL.h"

using namespace Rcpp;

#define FJFX_SUCCESS                         (0)     // Extraction succeeded, minutiae data is in output buffer.
#define FJFX_FAIL_IMAGE_SIZE_NOT_SUP         (1)     // Failed. Input image size was too large or too small.
#define FJFX_FAIL_EXTRACTION_UNSPEC          (2)     // Failed. Unknown error.
#define FJFX_FAIL_EXTRACTION_BAD_IMP         (3)     // Failed. No fingerprint detected in input image.
#define FJFX_FAIL_INVALID_OUTPUT_FORMAT      (7)     // Failed. Invalid output record type - only ANSI INCIT 378-2004 or ISO/IEC 19794-2:2005 are supported.
#define FJFX_FAIL_OUTPUT_BUFFER_IS_TOO_SMALL (8)     // Failed. Output buffer too small. 
#define FJFX_FMD_ANSI_378_2004        (0x001B0201)   // ANSI INCIT 378-2004 data format
#define FJFX_FMD_ISO_19794_2_2005     (0x01010001)   // ISO/IEC 19794-2:2005 data format
#define FJFX_FMD_BUFFER_SIZE          (34 + 256 * 6) // Output data buffer must be at least this size, in bytes (34 bytes for header + 6 bytes per minutiae point, for up to 256 minutiae points)
#define CBEFF (0x00330502)

struct dpHandle {
  FRFXLL_HANDLE h;
  
  explicit dpHandle(FRFXLL_HANDLE _h = NULL) : h(_h) {}
  
  ~dpHandle() {
    if (h)
      Close();
  }
  
  FRFXLL_RESULT Close() {
    FRFXLL_RESULT rc = FRFXLL_OK;
    if (h) {
      rc = FRFXLLCloseHandle(&h);
    }
    h = NULL;
    return rc;
  }
  
  operator FRFXLL_HANDLE() const  { return h; }
  FRFXLL_HANDLE* operator &()     { return &h; }
};

#define Check(x, err) { if ((x) < FRFXLL_OK) return err; }
#define CheckFx(x)    Check(x, FJFX_FAIL_EXTRACTION_UNSPEC);


int fjfx_create_fmd_from_raw(
    const void *raw_image,
    const unsigned short dpi,
    const unsigned short height,
    const unsigned short width,
    const unsigned int output_format,
    void   *fmd,
    unsigned int *size_of_fmd_ptr
) {
  if (fmd == NULL)       return FJFX_FAIL_EXTRACTION_UNSPEC;
  if (raw_image == NULL) return FJFX_FAIL_EXTRACTION_BAD_IMP;
  if (width > 2000 || height > 2000)                         return FJFX_FAIL_IMAGE_SIZE_NOT_SUP;
  if (dpi < 300 || dpi > 1024)                               return FJFX_FAIL_IMAGE_SIZE_NOT_SUP;
  if (width * 500 < 150 * dpi  || width * 500 > 812 * dpi)   return FJFX_FAIL_IMAGE_SIZE_NOT_SUP; // in range 0.3..1.62 in
  if (height * 500 < 150 * dpi || height * 500 > 1000 * dpi) return FJFX_FAIL_IMAGE_SIZE_NOT_SUP; // in range 0.3..2.0 in
  size_t size = size_of_fmd_ptr ? *size_of_fmd_ptr : FJFX_FMD_BUFFER_SIZE;
  if (size < FJFX_FMD_BUFFER_SIZE)                           return FJFX_FAIL_OUTPUT_BUFFER_IS_TOO_SMALL;
  FRFXLL_DATA_TYPE dt = 0;
  switch (output_format) {
  case FJFX_FMD_ANSI_378_2004:    dt = FRFXLL_DT_ANSI_FEATURE_SET; break;
  case FJFX_FMD_ISO_19794_2_2005: dt = FRFXLL_DT_ISO_FEATURE_SET; break;
  default:
    return FJFX_FAIL_INVALID_OUTPUT_FORMAT;
  }
  dpHandle hContext, hFtrSet;
  CheckFx( FRFXLLCreateLibraryContext(&hContext) );
  switch ( FRFXLLCreateFeatureSetFromRaw(hContext, reinterpret_cast<const unsigned char *>(raw_image), width * height, width, height, dpi, FRFXLL_FEX_ENABLE_ENHANCEMENT, &hFtrSet ) ) {
  case FRFXLL_OK: 
    break;
  case FRFXLL_ERR_FB_TOO_SMALL_AREA:
    return FJFX_FAIL_EXTRACTION_BAD_IMP;
  default: 
    return FJFX_FAIL_EXTRACTION_UNSPEC;
  }
  const unsigned short dpcm = (dpi * 100 + 50) / 254;
  const unsigned char finger_quality  = 60;  // Equivalent to NFIQ value 3 
  const unsigned char finger_position = 0;   // Unknown finger
  const unsigned char impression_type = 0;   // Live-scan plain
  FRFXLL_OUTPUT_PARAM_ISO_ANSI param = {sizeof(FRFXLL_OUTPUT_PARAM_ISO_ANSI), CBEFF, finger_position, 0, dpcm, dpcm, width, height, 0, finger_quality, impression_type};
  unsigned char * tmpl = reinterpret_cast<unsigned char *>(fmd);
  CheckFx( FRFXLLExport(hFtrSet, dt, &param, tmpl, &size) );
  if (size_of_fmd_ptr) *size_of_fmd_ptr = (unsigned int)size;
  CheckFx( FRFXLLCloseHandle(&hFtrSet) );
  CheckFx( FRFXLLCloseHandle(&hContext) );
  return FJFX_SUCCESS;
}

// [[Rcpp::export]]
int FJFX_extract_minutiae_from_PGM(std::string inputfile, std::string outputfile) {
  FILE *fp = 0;
  int height, width, gray;
  unsigned int size;
  void * image = 0;
  size_t n;
  int err;
  unsigned char tmpl[FJFX_FMD_BUFFER_SIZE] = {0};
  
  fp = fopen(inputfile.c_str(), "rb");
  if (fp == 0) {
    printf("Cannot open image file: %s\n", inputfile.c_str());
    return 9;
  }
  n = fscanf(fp, "P5%d%d%d", &width, &height, &gray); 
  if (n != 3 || 
      gray > 256 || width > 0xffff || height > 0xffff || 
      gray <= 1 || width < 32 || height < 32) {
    printf("Image file %s is in unsupported format\n", inputfile.c_str());
    fclose(fp);
    return 10;
  }
  
  size = width * height;
  image = malloc(size);
  if (image == 0) {
    printf("Cannot allocate image buffer: image size is %dx%d", width, height);
    if(fp != 0) {
      fclose(fp); fp = 0;
    }
    return 12;
  }
  
  n = fread(image, 1, size, fp);
  fclose(fp); fp = 0;
  if (n != size) {
    printf("Image file %s is too short\n", inputfile.c_str());
    free(image);
    return 11;
  }
  
  size = FJFX_FMD_BUFFER_SIZE;
  err = fjfx_create_fmd_from_raw(image, 500, height, width, FJFX_FMD_ISO_19794_2_2005, tmpl, &size);
  free(image); image = 0;
  if (err != FJFX_SUCCESS) {
    printf("Failed feature extraction\n");
    return err;
  }
  
  fp = fopen(outputfile.c_str(), "wb");
  if (fp == 0) {
    printf("Cannot create output file: %s\n", outputfile.c_str());
    return 14;
  }
  n = fwrite(tmpl, 1, size, fp);
  fclose(fp);
  if (n != size) {
    printf("Cannot write output file of size %d\n", (int)size);
    free(image);
    return 15;
  }
  return 0;
}



