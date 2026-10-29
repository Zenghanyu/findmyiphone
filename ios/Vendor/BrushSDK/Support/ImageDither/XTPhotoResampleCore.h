#ifndef XTPhotoResampleCore_h
#define XTPhotoResampleCore_h

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque, gamma-encoded sRGB RGBA8, alpha must already be composited on white.
 * Returns 1 on success, 0 on invalid input/allocation failure. Buffers must not
 * overlap. Output is opaque. Strength is clamped to [0,1]; use 0 for resampling
 * alone. Equal-size/enlarged images are not sharpened.
 */
int XTPhotoResampleRGBA(const uint8_t *source, size_t sourceWidth, size_t sourceHeight,
                        size_t sourceStride, uint8_t *output, size_t outputWidth,
                        size_t outputHeight, size_t outputStride, double strength);

/* DPID-style area-footprint inverse bilateral downsampling (engineering variant).
 * First integrate exact source-pixel coverage, then smooth that reference with
 * [1,6,1]^2/64. Within each footprint reweight source pixels by their weighted
 * RGB distance from the reference, raised to exponent. RGB uses ONE shared weight.
 * Range distance floor is 2/255; maxWeightRatio limits max/min range weights.
 * blend mixes the adaptive result with the area reference. No post sharpening.
 * Aggressive defaults: exponent=1.5, maxWeightRatio=32, blend=.9.
 * Legal ranges: exponent [0,4], ratio [1,256], blend [0,1].
 * Identity/enlargement/mixed-axis enlargement falls back to unsharpened Lanczos.
 * Same opaque RGBA/stride/non-overlap contract as XTPhotoResampleRGBA.
 */
int XTPhotoDPIDResampleRGBA(const uint8_t *source, size_t sourceWidth, size_t sourceHeight,
                           size_t sourceStride, uint8_t *output, size_t outputWidth,
                           size_t outputHeight, size_t outputStride, double exponent,
                           double maxWeightRatio, double blend);

/* In-place, bounded luminance enhancement; exported for cross-platform tests. */
int XTPhotoEnhanceRGBA(uint8_t *pixels, size_t width, size_t height,
                       size_t stride, double strength);

/* UIKit UIImageOrientation numeric values (0..7). Map an upright/display crop
 * to raw CGImage normalized coordinates without rasterizing the whole photo.
 * Apply 0..3 clockwise quarter turns after cropping; output orientation includes
 * both EXIF orientation and the user rotation. rect = {x,y,width,height}.
 */
int XTPhotoMapCrop(const double rect[4], int imageOrientation, int clockwiseQuarterTurns,
                   double rawRect[4], int *outputOrientation);

#ifdef __cplusplus
}
#endif
#endif
