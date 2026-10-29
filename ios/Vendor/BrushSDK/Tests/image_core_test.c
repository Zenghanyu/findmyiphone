#include "XTInkPhotoCore.h"
#include "XTPhotoResampleCore.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    const size_t width = 240, count = width * width;
    uint8_t *source = malloc(480 * 480 * 4);
    uint8_t *small = malloc(count * 4);
    uint8_t *codes = malloc(count);
    uint8_t *markers = malloc(count * 4);
    assert(source && small && codes && markers);
    memset(source, 255, 480 * 480 * 4);
    assert(XTPhotoDPIDResampleRGBA(source, 480, 480, 480 * 4, small, width, width, width * 4, 1.5, 32, .9));
    for (size_t i = 0; i < count * 4; i++) assert(small[i] == 255);
    puts("PASS DPID preserves constant white and opaque alpha");
    assert(XTInkQuantizeRGBA(small, width, width, width * 4, codes, width, 1, 0, .55));
    for (size_t i = 0; i < count; i++) assert(codes[i] == 1);
    puts("PASS white input uses the white protocol index");
    assert(XTInkRenderIndices(codes, width, width, width, markers, width * 4, 0, 0, 0));
    const XTInkProfile *profile = XTInkHinkT0154A10A2();
    for (size_t colour = 0; colour < 6; colour++) {
        memset(codes, profile->colors[colour].code, count);
        assert(XTInkRenderIndices(codes, width, width, width, markers, width * 4, 0, 0, 0));
        for (size_t pixel = 0; pixel < count; pixel++) {
            assert(memcmp(markers + pixel * 4, profile->colors[colour].marker, 3) == 0);
            assert(markers[pixel * 4 + 3] == 255);
        }
    }
    puts("PASS all six marker colours match their protocol indices");
    codes[0] = 4;
    assert(!XTInkRenderIndices(codes, width, width, width, markers, width * 4, 0, 0, 0));
    assert(!XTInkQuantizeRGBA(small, 200, 200, width * 4, codes, width, 1, 0, .55));
    assert(!XTPhotoDPIDResampleRGBA(NULL, 480, 480, 480 * 4, small, width, width, width * 4, 1.5, 32, .9));
    puts("PASS unknown indices, incorrect panel dimensions and invalid buffers are rejected");
    double rect[4] = {.1, .2, .5, .5}, raw[4];
    int orientation = -1;
    assert(XTPhotoMapCrop(rect, 0, 0, raw, &orientation));
    assert(raw[0] == rect[0] && raw[1] == rect[1] && orientation == 0);
    puts("PASS upright source crop maps without a screenshot conversion");
    free(source); free(small); free(codes); free(markers);
    return 0;
}
