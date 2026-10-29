"""Portable model of the old iOS pipeline and the proposed photo resampler.

UIKit's undocumented default interpolation is NOT reproduced bit for bit.
legacy_resize models its geometry with selectable Pillow filters. The new
Lanczos-3 + bounded luminance enhancement has a matching portable C core.
All arrays are opaque, gamma-encoded sRGB RGB, in the 0..255 range.
"""
from __future__ import annotations

import numpy as np
from PIL import Image
from scipy.ndimage import convolve, maximum_filter, minimum_filter


def legacy_resize(image: Image.Image, size: tuple[int, int], view_width=350,
                  screen_scale=2, interpolation="bilinear", crop=(0, 0, 1, 1)) -> Image.Image:
    """Model layer screenshot -> optional crop/height minus 1 -> drawInRect.

    A view width is in points; screenshot size is in pixels. The original crop
    helper subtracts one from the crop height, except its full-bounds fast path.
    Crop is normalized (x,y,width,height) in displayed image coordinates.
    No SDK dithering is used.
    """
    filters = {"bilinear": Image.Resampling.BILINEAR,
               "bicubic": Image.Resampling.BICUBIC,
               "lanczos": Image.Resampling.LANCZOS}
    f = filters[interpolation]
    w = round(view_width * screen_scale)
    h = round(w * image.height / image.width)
    screenshot = image.convert("RGB").resize((w, h), f)
    if crop != (0, 0, 1, 1):
        x, y, cw, ch = crop
        left, top = round(x * w), round(y * h)
        screenshot = screenshot.crop((left, top, round((x + cw) * w), max(top + 1, round((y + ch) * h) - 1)))
    return screenshot.resize(size, f)


def _axis_table(source: int, target: int):
    scale = max(source / target, 1.0)
    result = []
    for i in range(target):
        center = (i + 0.5) * source / target - 0.5
        taps = np.arange(int(np.ceil(center - 3 * scale)),
                         int(np.floor(center + 3 * scale)) + 1)
        d = (taps - center) / scale
        weights = np.sinc(d) * np.sinc(d / 3)
        weights[np.abs(d) >= 3] = 0
        weights /= weights.sum()
        # Limit ringing to the values within the output pixel's source footprint.
        central = np.abs(taps - center) <= scale / 2 + 0.5 + 1e-9
        result.append((np.clip(taps, 0, source - 1), weights, central))
    return result


def lanczos3(rgb: np.ndarray, size: tuple[int, int]) -> np.ndarray:
    rgb = np.asarray(rgb, dtype=np.float64)
    h, w, _ = rgb.shape
    tw, th = size
    if tw == w and th == h:
        return rgb.copy()
    tmp = np.empty((h, tw, 3), dtype=np.float64)
    for x, (ids, weights, central) in enumerate(_axis_table(w, tw)):
        samples = rgb[:, ids]
        v = np.einsum("hkc,k->hc", samples, weights)
        tmp[:, x] = np.clip(v, samples[:, central].min(1), samples[:, central].max(1))
    out = np.empty((th, tw, 3), dtype=np.float64)
    for y, (ids, weights, central) in enumerate(_axis_table(h, th)):
        samples = tmp[ids]
        v = np.einsum("kwc,k->wc", samples, weights)
        out[y] = np.clip(v, samples[central].min(0), samples[central].max(0))
    return np.floor(np.clip(out, 0, 255) + 0.5).astype(np.uint8)


def enhance(rgb: np.ndarray, strength=0.65) -> np.ndarray:
    """Suppress changes to smooth/noisy areas; cap change and forbid new extrema."""
    rgb = np.asarray(rgb, dtype=np.float64)
    y = rgb @ np.array([0.2126, 0.7152, 0.0722])
    blur = convolve(y, np.outer([1, 2, 1], [1, 2, 1]) / 16, mode="nearest")
    lo, hi = minimum_filter(y, 3, mode="nearest"), maximum_filter(y, 3, mode="nearest")
    detail = y - blur

    def smoothstep(a, b, value):
        t = np.clip((value - a) / (b - a), 0, 1)
        return t * t * (3 - 2 * t)

    delta = strength * detail * smoothstep(2, 8, np.abs(detail)) * smoothstep(8, 32, hi - lo)
    cap = np.minimum(8, 0.12 * (hi - lo))
    delta = np.clip(delta, -cap, cap)
    delta = np.clip(delta, lo - y, hi - y)
    delta = np.clip(delta, -rgb.min(2), 255 - rgb.max(2))
    return np.floor(np.clip(rgb + delta[:, :, None], 0, 255) + 0.5).astype(np.uint8)


def photo_resize(image: Image.Image, size: tuple[int, int], strength=0.65) -> Image.Image:
    out = lanczos3(np.asarray(image.convert("RGB")), size)
    # Resizing to equal/larger dimensions must not repeatedly sharpen an image.
    if image.width > size[0] or image.height > size[1]:
        out = enhance(out, strength)
    return Image.fromarray(np.asarray(out, dtype=np.uint8))
