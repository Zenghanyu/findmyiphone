#ifndef XTInkPhotoCore_h
#define XTInkPhotoCore_h
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

/* HINK-T0154A10-A2, p13 typical values at 20<T<=30 C.
 * Lab is provisionally interpreted as D65/2deg; not device calibration.
 * Codes are existing App/SDK conventions, not panel SPI bit definitions.
 */
typedef struct {
    uint8_t code;
    uint8_t marker[3];
    double lab[3];
} XTInkColor;
typedef struct {
    const char *name;
    size_t width, height;
    double activeWidthMM, activeHeightMM;
    XTInkColor colors[6];
} XTInkProfile;

const XTInkProfile *XTInkHinkT0154A10A2(void);

/* Target-resolution opaque sRGB RGBA8. Quantizes exactly once to existing App
 * codes {0,1,2,3,5,6}. Input and output must not overlap. All storage caller-owned.
 * detailStrength [0,1], default .8; edgeProtection [0,1], default .55.
 * dither=0 selects nearest colour with no diffusion (App colour-level mode).
 * A 240x240 profile is intentionally required; no accidental reuse on other panels.
 */
int XTInkQuantizeRGBA(const uint8_t *rgba, size_t width, size_t height, size_t stride,
                      uint8_t *codes, size_t codeStride, int dither,
                      double detailStrength, double edgeProtection);

/* Exact protocol markers (physicalPreview=0) or nominal D65 sRGB preview (1).
 * Both images are derived from the SAME index map, with optional payload flips.
 * Returns 0 for an unknown code; never silently maps it to black.
 */
int XTInkRenderIndices(const uint8_t *codes, size_t width, size_t height, size_t codeStride,
                       uint8_t *rgba, size_t stride, int physicalPreview,
                       int flipHorizontal, int flipVertical);

/* Diagnostics/reference model: interleaved XYZ and source Lab (width*height*3
 * doubles). Same preparation used by the quantizer, for native/Python parity.
 */
int XTInkPrepareRGBA(const uint8_t *rgba, size_t width, size_t height, size_t stride,
                     double detailStrength, double *xyz, double *lab);
#ifdef __cplusplus
}
#endif
#endif
