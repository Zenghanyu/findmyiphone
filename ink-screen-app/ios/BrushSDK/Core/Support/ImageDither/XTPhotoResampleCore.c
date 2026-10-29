#include "XTPhotoResampleCore.h"
#include <float.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    int first, count;
    double center, scale;
    double *weights;
} XTPhotoFilter;

static double XTClamp(double v, double lo, double hi) { return fmax(lo, fmin(v, hi)); }
static int XTIndex(int v, int n) { return v < 0 ? 0 : (v >= n ? n - 1 : v); }
static uint8_t XTByte(double v) { return (uint8_t)floor(XTClamp(v, 0, 255) + 0.5); }
static double XTSmooth(double a, double b, double v) {
    double t = XTClamp((v - a) / (b - a), 0, 1);
    return t * t * (3 - 2 * t);
}
static double XTSinc(double x) {
    if (fabs(x) < 1e-12) return 1;
    x *= 3.14159265358979323846;
    return sin(x) / x;
}
static int XTValid(size_t w, size_t h, size_t stride) {
    return w > 0 && h > 0 && w <= 32768 && h <= 32768 &&
           stride >= w * 4 && stride <= SIZE_MAX / h;
}

int XTPhotoMapCrop(const double rect[4], int orientation, int turns, double raw[4], int *outputOrientation) {
    if (!rect || !raw || !outputOrientation || orientation < 0 || orientation > 7 || turns < 0 || turns > 3) return 0;
    double x = rect[0], y = rect[1], w = rect[2], h = rect[3];
    if (!isfinite(x) || !isfinite(y) || !isfinite(w) || !isfinite(h) ||
        x < 0 || y < 0 || w <= 0 || h <= 0 || x + w > 1 + 1e-9 || y + h > 1 + 1e-9) return 0;
    switch (orientation) {
        case 0: raw[0] = x; raw[1] = y; raw[2] = w; raw[3] = h; break;
        case 1: raw[0] = 1-x-w; raw[1] = 1-y-h; raw[2] = w; raw[3] = h; break;
        case 2: raw[0] = 1-y-h; raw[1] = x; raw[2] = h; raw[3] = w; break;
        case 3: raw[0] = y; raw[1] = 1-x-w; raw[2] = h; raw[3] = w; break;
        case 4: raw[0] = 1-x-w; raw[1] = y; raw[2] = w; raw[3] = h; break;
        case 5: raw[0] = x; raw[1] = 1-y-h; raw[2] = w; raw[3] = h; break;
        case 6: raw[0] = y; raw[1] = x; raw[2] = h; raw[3] = w; break;
        case 7: raw[0] = 1-y-h; raw[1] = 1-x-w; raw[2] = h; raw[3] = w; break;
    }
    const int cycles[2][4] = {{0, 3, 1, 2}, {4, 7, 5, 6}};
    int mirrored = orientation >= 4;
    for (int i = 0; i < 4; ++i) {
        if (cycles[mirrored][i] == orientation) {
            *outputOrientation = cycles[mirrored][(i + turns) % 4];
            break;
        }
    }
    return 1;
}
static void XTFreeFilters(XTPhotoFilter *filters, size_t count) {
    if (!filters) return;
    for (size_t i = 0; i < count; ++i) free(filters[i].weights);
    free(filters);
}
static XTPhotoFilter *XTMakeFilters(size_t source, size_t target) {
    XTPhotoFilter *filters = calloc(target, sizeof(*filters));
    if (!filters) return NULL;
    double ratio = (double)source / target;
    double scale = fmax(ratio, 1);
    for (size_t i = 0; i < target; ++i) {
        XTPhotoFilter *f = &filters[i];
        f->center = (i + 0.5) * ratio - 0.5;
        f->scale = scale;
        f->first = (int)ceil(f->center - 3 * scale);
        f->count = (int)floor(f->center + 3 * scale) - f->first + 1;
        f->weights = malloc((size_t)f->count * sizeof(double));
        if (!f->weights) { XTFreeFilters(filters, target); return NULL; }
        double sum = 0;
        for (int k = 0; k < f->count; ++k) {
            double d = (f->first + k - f->center) / scale;
            double weight = fabs(d) < 3 ? XTSinc(d) * XTSinc(d / 3) : 0;
            f->weights[k] = weight;
            sum += weight;
        }
        if (fabs(sum) < 1e-12) { XTFreeFilters(filters, target); return NULL; }
        for (int k = 0; k < f->count; ++k) f->weights[k] /= sum;
    }
    return filters;
}

int XTPhotoEnhanceRGBA(uint8_t *pixels, size_t w, size_t h, size_t stride, double strength) {
    if (!pixels || !XTValid(w, h, stride) || !isfinite(strength)) return 0;
    strength = XTClamp(strength, 0, 1);
    if (strength == 0) return 1;
    if (w > SIZE_MAX / h / sizeof(double)) return 0;
    double *luma = malloc(w * h * sizeof(double));
    if (!luma) return 0;
    for (size_t y = 0; y < h; ++y) for (size_t x = 0; x < w; ++x) {
        const uint8_t *p = pixels + y * stride + x * 4;
        luma[y * w + x] = .2126 * p[0] + .7152 * p[1] + .0722 * p[2];
    }
    const int kernel[3] = {1, 2, 1};
    for (size_t y = 0; y < h; ++y) for (size_t x = 0; x < w; ++x) {
        double lo = DBL_MAX, hi = -DBL_MAX, blur = 0;
        for (int j = -1; j <= 1; ++j) for (int i = -1; i <= 1; ++i) {
            double v = luma[(size_t)XTIndex((int)y + j, (int)h) * w + XTIndex((int)x + i, (int)w)];
            lo = fmin(lo, v); hi = fmax(hi, v);
            blur += v * kernel[i + 1] * kernel[j + 1] / 16.0;
        }
        double center = luma[y * w + x], detail = center - blur;
        double delta = strength * detail * XTSmooth(2, 8, fabs(detail)) * XTSmooth(8, 32, hi - lo);
        double cap = fmin(8, .12 * (hi - lo));
        delta = XTClamp(delta, -cap, cap);
        delta = XTClamp(delta, lo - center, hi - center);
        uint8_t *p = pixels + y * stride + x * 4;
        double rgbMin = fmin(p[0], fmin(p[1], p[2])), rgbMax = fmax(p[0], fmax(p[1], p[2]));
        delta = XTClamp(delta, -rgbMin, 255 - rgbMax);
        for (int c = 0; c < 3; ++c) p[c] = XTByte(p[c] + delta);
    }
    free(luma);
    return 1;
}

int XTPhotoResampleRGBA(const uint8_t *source, size_t sw, size_t sh, size_t sourceStride,
                        uint8_t *output, size_t dw, size_t dh, size_t outputStride, double strength) {
    if (!source || !output || source == output || !XTValid(sw, sh, sourceStride) ||
        !XTValid(dw, dh, outputStride) || !isfinite(strength)) return 0;
    if (sw == dw && sh == dh) {
        for (size_t y = 0; y < dh; ++y) {
            memcpy(output + y * outputStride, source + y * sourceStride, dw * 4);
            for (size_t x = 0; x < dw; ++x) output[y * outputStride + x * 4 + 3] = 255;
        }
        return 1;
    }
    if (dw > SIZE_MAX / sh / (3 * sizeof(double))) return 0;
    double *horizontal = malloc(sh * dw * 3 * sizeof(double));
    XTPhotoFilter *fx = XTMakeFilters(sw, dw), *fy = XTMakeFilters(sh, dh);
    if (!horizontal || !fx || !fy) {
        free(horizontal); XTFreeFilters(fx, dw); XTFreeFilters(fy, dh); return 0;
    }
    for (size_t y = 0; y < sh; ++y) for (size_t x = 0; x < dw; ++x) {
        const XTPhotoFilter *f = &fx[x];
        double v[3] = {0}, lo[3] = {DBL_MAX, DBL_MAX, DBL_MAX}, hi[3] = {-DBL_MAX, -DBL_MAX, -DBL_MAX};
        for (int k = 0; k < f->count; ++k) {
            int index = f->first + k;
            const uint8_t *p = source + y * sourceStride + (size_t)XTIndex(index, (int)sw) * 4;
            int central = fabs(index - f->center) <= f->scale / 2 + .5 + 1e-9;
            for (int c = 0; c < 3; ++c) {
                v[c] += p[c] * f->weights[k];
                if (central) { lo[c] = fmin(lo[c], p[c]); hi[c] = fmax(hi[c], p[c]); }
            }
        }
        for (int c = 0; c < 3; ++c) horizontal[(y * dw + x) * 3 + c] = XTClamp(v[c], lo[c], hi[c]);
    }
    for (size_t y = 0; y < dh; ++y) for (size_t x = 0; x < dw; ++x) {
        const XTPhotoFilter *f = &fy[y];
        double v[3] = {0}, lo[3] = {DBL_MAX, DBL_MAX, DBL_MAX}, hi[3] = {-DBL_MAX, -DBL_MAX, -DBL_MAX};
        for (int k = 0; k < f->count; ++k) {
            int index = f->first + k;
            const double *p = horizontal + ((size_t)XTIndex(index, (int)sh) * dw + x) * 3;
            int central = fabs(index - f->center) <= f->scale / 2 + .5 + 1e-9;
            for (int c = 0; c < 3; ++c) {
                v[c] += p[c] * f->weights[k];
                if (central) { lo[c] = fmin(lo[c], p[c]); hi[c] = fmax(hi[c], p[c]); }
            }
        }
        uint8_t *p = output + y * outputStride + x * 4;
        for (int c = 0; c < 3; ++c) p[c] = XTByte(XTClamp(v[c], lo[c], hi[c]));
        p[3] = 255;
    }
    free(horizontal); XTFreeFilters(fx, dw); XTFreeFilters(fy, dh);
    return (sw > dw || sh > dh) ? XTPhotoEnhanceRGBA(output, dw, dh, outputStride, strength) : 1;
}

static double XTDPIDRangeWeight(const uint8_t *pixel, const double *guide, double exponent) {
    double r = pixel[0] - guide[0], g = pixel[1] - guide[1], b = pixel[2] - guide[2];
    double distanceSquared = .2126 * r * r + .7152 * g * g + .0722 * b * b;
    return pow(fmax(distanceSquared, 4), exponent / 2);
}

static uint8_t XTDPIDByte(double value) {
    // Stabilize exact half-integer area means across equivalent FP summations.
    return (uint8_t)floor(XTClamp(value, 0, 255) + .5 + 1e-9);
}

int XTPhotoDPIDResampleRGBA(const uint8_t *source, size_t sw, size_t sh, size_t sourceStride,
                           uint8_t *output, size_t dw, size_t dh, size_t outputStride,
                           double exponent, double ratio, double blend) {
    if (!source || !output || source == output || !XTValid(sw, sh, sourceStride) ||
        !XTValid(dw, dh, outputStride) || !isfinite(exponent) || !isfinite(ratio) || !isfinite(blend) ||
        exponent < 0 || exponent > 4 || ratio < 1 || ratio > 256 || blend < 0 || blend > 1) return 0;
    if (dw > sw || dh > sh || (dw == sw && dh == sh)) {
        return XTPhotoResampleRGBA(source, sw, sh, sourceStride, output, dw, dh, outputStride, 0);
    }
    if (dw > SIZE_MAX / dh / (3 * sizeof(double))) return 0;
    double *base = calloc(dw * dh * 3, sizeof(double));
    if (!base) return 0;
    // Integrate source pixel cells: fractional scales and crop phases retain
    // their actual coverage rather than rounding source blocks to integer boxes.
    for (size_t y = 0; y < dh; ++y) {
        double top = (double)y * sh / dh, bottom = (double)(y + 1) * sh / dh;
        for (size_t x = 0; x < dw; ++x) {
            double left = (double)x * sw / dw, right = (double)(x + 1) * sw / dw;
            double *mean = base + (y * dw + x) * 3, total = 0;
            size_t endY = (size_t)fmin(sh, ceil(bottom)), endX = (size_t)fmin(sw, ceil(right));
            for (size_t yy = (size_t)floor(top); yy < endY; ++yy) {
                double wy = fmax(0, fmin(bottom, yy + 1) - fmax(top, yy));
                for (size_t xx = (size_t)floor(left); xx < endX; ++xx) {
                    double weight = wy * fmax(0, fmin(right, xx + 1) - fmax(left, xx));
                    const uint8_t *pixel = source + yy * sourceStride + xx * 4;
                    total += weight;
                    for (int c = 0; c < 3; ++c) mean[c] += weight * pixel[c];
                }
            }
            for (int c = 0; c < 3; ++c) mean[c] /= total;
        }
    }
    const int kernel[3] = {1, 6, 1};
    for (size_t y = 0; y < dh; ++y) {
        double top = (double)y * sh / dh, bottom = (double)(y + 1) * sh / dh;
        for (size_t x = 0; x < dw; ++x) {
            double left = (double)x * sw / dw, right = (double)(x + 1) * sw / dw;
            size_t endY = (size_t)fmin(sh, ceil(bottom)), endX = (size_t)fmin(sw, ceil(right));
            double guide[3] = {0};
            for (int j = -1; j <= 1; ++j) for (int i = -1; i <= 1; ++i) {
                const double *neighbor = base + ((size_t)XTIndex((int)y + j, (int)dh) * dw + XTIndex((int)x + i, (int)dw)) * 3;
                double weight = kernel[j + 1] * kernel[i + 1] / 64.0;
                for (int c = 0; c < 3; ++c) guide[c] += neighbor[c] * weight;
            }
            double minimum = DBL_MAX, maximum = 0;
            for (size_t yy = (size_t)floor(top); yy < endY; ++yy) {
                for (size_t xx = (size_t)floor(left); xx < endX; ++xx) {
                    const uint8_t *pixel = source + yy * sourceStride + xx * 4;
                    double raw = XTDPIDRangeWeight(pixel, guide, exponent);
                    minimum = fmin(minimum, raw); maximum = fmax(maximum, raw);
                }
            }
            // Equal range weights are exactly area sampling. Avoid floating
            // cancellation turning a half-integer mean into a false noise change.
            if (maximum <= minimum * (1 + 1e-12) || ratio == 1 || blend == 0) {
                uint8_t *pixel = output + y * outputStride + x * 4;
                const double *mean = base + (y * dw + x) * 3;
                for (int c = 0; c < 3; ++c) pixel[c] = XTDPIDByte(mean[c]);
                pixel[3] = 255;
                continue;
            }
            double value[3] = {0}, total = 0;
            for (size_t yy = (size_t)floor(top); yy < endY; ++yy) {
                double wy = fmax(0, fmin(bottom, yy + 1) - fmax(top, yy));
                for (size_t xx = (size_t)floor(left); xx < endX; ++xx) {
                    double coverage = wy * fmax(0, fmin(right, xx + 1) - fmax(left, xx));
                    const uint8_t *pixel = source + yy * sourceStride + xx * 4;
                    double weight = coverage * fmin(XTDPIDRangeWeight(pixel, guide, exponent), minimum * ratio);
                    total += weight;
                    for (int c = 0; c < 3; ++c) value[c] += weight * pixel[c];
                }
            }
            uint8_t *pixel = output + y * outputStride + x * 4;
            const double *mean = base + (y * dw + x) * 3;
            for (int c = 0; c < 3; ++c) pixel[c] = XTDPIDByte(mean[c] + blend * (value[c] / total - mean[c]));
            pixel[3] = 255;
        }
    }
    free(base);
    return 1;
}
