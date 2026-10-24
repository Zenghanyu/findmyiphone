"""Compile the exact App C core on Windows, then test it against the Python model.

This is not an iOS build and cannot validate UIKit orientation/color management.
"""
from __future__ import annotations

import argparse
import ctypes
import json
import os
import subprocess
import time
from pathlib import Path

import numpy as np

from experiment import fixtures
from resample import enhance, lanczos3, photo_resize


ROOT = Path(__file__).resolve().parent
CORE = ROOT.parents[1] / "ios/BrushSDK/Core/Support/ImageDither/XTPhotoResampleCore.c"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, default=Path(os.environ.get("XT_ZIG", ROOT / ".runtime/ziglang/zig.exe")))
    args = parser.parse_args()
    build = ROOT / ".build"
    build.mkdir(exist_ok=True)
    dll = build / "photo_resample.dll"
    subprocess.run([str(args.compiler), "cc", "-std=c11", "-O2", "-Wall", "-Wextra", "-Werror",
                    "-shared", "-Wl,--export-all-symbols", str(CORE), "-o", str(dll)], check=True)
    lib = ctypes.CDLL(str(dll))
    ptr = ctypes.POINTER(ctypes.c_uint8)
    lib.XTPhotoResampleRGBA.argtypes = [ptr, ctypes.c_size_t, ctypes.c_size_t, ctypes.c_size_t,
                                      ptr, ctypes.c_size_t, ctypes.c_size_t, ctypes.c_size_t, ctypes.c_double]
    lib.XTPhotoResampleRGBA.restype = ctypes.c_int
    lib.XTPhotoEnhanceRGBA.argtypes = [ptr, ctypes.c_size_t, ctypes.c_size_t, ctypes.c_size_t, ctypes.c_double]
    lib.XTPhotoEnhanceRGBA.restype = ctypes.c_int
    dptr = ctypes.POINTER(ctypes.c_double)
    lib.XTPhotoMapCrop.argtypes = [dptr, ctypes.c_int, ctypes.c_int, dptr, ctypes.POINTER(ctypes.c_int)]
    lib.XTPhotoMapCrop.restype = ctypes.c_int

    def native(rgb, size, strength=.65, padding=0):
        h, w, _ = rgb.shape
        source = np.full((h, w * 4 + padding), 77, dtype=np.uint8)
        source[:, :w * 4].reshape(h, w, 4)[:, :, :3] = rgb
        source[:, :w * 4].reshape(h, w, 4)[:, :, 3] = 255
        tw, th = size
        output = np.full((th, tw * 4 + padding), 91, dtype=np.uint8)
        result = lib.XTPhotoResampleRGBA(source.ctypes.data_as(ptr), w, h, source.strides[0],
                                        output.ctypes.data_as(ptr), tw, th, output.strides[0], strength)
        assert result == 1
        assert np.all(output[:, tw * 4:] == 91), "Output stride padding overwritten"
        rgba = output[:, :tw * 4].reshape(th, tw, 4)
        assert np.all(rgba[:, :, 3] == 255)
        return rgba[:, :, :3].copy()

    records = []

    def record(name, **values):
        records.append({"test": name, "passed": True, **values})
        print(name, "PASS", values, flush=True)

    rng = np.random.default_rng(20261023)
    # Independent Pillow/EXIF geometry oracle for the App's zero-copy crop mapping.
    transforms = [None, Image.Transpose.ROTATE_180, Image.Transpose.ROTATE_90,
                  Image.Transpose.ROTATE_270, Image.Transpose.FLIP_LEFT_RIGHT,
                  Image.Transpose.FLIP_TOP_BOTTOM, Image.Transpose.TRANSPOSE, Image.Transpose.TRANSVERSE]
    raw_image = Image.fromarray(rng.integers(0, 256, (80, 100, 3), dtype=np.uint8))
    rect = (ctypes.c_double * 4)(.1, .2, .6, .5)
    for orientation in range(8):
        displayed = raw_image.transpose(transforms[orientation]) if transforms[orientation] is not None else raw_image
        expected_crop = displayed.crop((round(displayed.width * .1), round(displayed.height * .2),
                                         round(displayed.width * .7), round(displayed.height * .7)))
        for turns in range(4):
            mapped, combined = (ctypes.c_double * 4)(), ctypes.c_int()
            assert lib.XTPhotoMapCrop(rect, orientation, turns, mapped, ctypes.byref(combined)) == 1
            x, y, w, h = mapped
            cropped = raw_image.crop((round(x * 100), round(y * 80), round((x + w) * 100), round((y + h) * 80)))
            actual = cropped.transpose(transforms[combined.value]) if transforms[combined.value] is not None else cropped
            expected = expected_crop.rotate(-90 * turns, expand=True)
            assert np.array_equal(np.array(actual), np.array(expected)), (orientation, turns, list(mapped), combined.value)
    record("all_8_exif_orientations_times_4_user_rotations", combinations=32)

    for sw, sh, dw, dh in [(97, 83, 29, 31), (19, 23, 41, 53), (33, 35, 33, 35),
                            (47, 29, 1, 1), (1, 31, 7, 11), (41, 1, 13, 5), (71, 59, 71, 19)]:
        src = rng.integers(0, 256, (sh, sw, 3), dtype=np.uint8)
        expected = lanczos3(src, (dw, dh))
        if sw > dw or sh > dh:
            expected = enhance(expected)
        actual = native(src, (dw, dh), padding=12)
        error = int(np.abs(actual.astype(int) - expected.astype(int)).max())
        assert error <= 1, (sw, sh, dw, dh, error)
        record(f"python_native_{sw}x{sh}_to_{dw}x{dh}", max_channel_error=error)

    src = rng.integers(0, 256, (75, 81, 3), dtype=np.uint8)
    assert np.array_equal(native(src, (81, 75)), src)
    record("identity_has_no_repeated_sharpening")

    for color in [(0, 0, 0), (255, 255, 255), (73, 141, 205), (0, 255, 0)]:
        src = np.full((107, 83, 3), color, dtype=np.uint8)
        actual = native(src, (31, 29))
        assert np.all(actual == color)
    record("constant_colors_and_neutral_backgrounds_unchanged")

    src = np.full((601, 607, 3), 50, dtype=np.uint8)
    src[:, 304:] = 200
    actual = native(src, (93, 91))
    assert actual.min() >= 50 and actual.max() <= 200
    assert np.max(np.abs(actual[:, 0].astype(int) - 50)) == 0
    assert np.max(np.abs(actual[:, -1].astype(int) - 200)) == 0
    record("gray_step_has_no_lanczos_overshoot_or_new_extrema")

    y, x = np.indices((1000, 1000))
    src = np.repeat((((x + y) % 2) * 255).astype(np.uint8)[:, :, None], 3, axis=2)
    actual = native(src, (50, 50))
    assert abs(float(actual.mean()) - 127.5) < 1 and actual.std() < 1
    record("checkerboard_antialiasing", std=float(actual.std()))

    src = rng.integers(0, 256, (240, 320, 3), dtype=np.uint8)
    base, detail = native(src, (103, 81), 0), native(src, (103, 81))
    delta = detail.astype(int) - base.astype(int)
    assert np.abs(delta).max() <= 8
    assert np.all(delta[:, :, 0] == delta[:, :, 1]) and np.all(delta[:, :, 1] == delta[:, :, 2])
    record("detail_cap_and_equal_rgb_delta", max_adjustment=int(np.abs(delta).max()))

    src = np.clip(np.round(128 + rng.normal(0, 1.5, (512, 512, 1))), 0, 255).astype(np.uint8)
    src = np.repeat(src, 3, axis=2)
    base, detail = native(src, (200, 200), 0), native(src, (200, 200))
    assert np.array_equal(base, detail)
    record("smooth_region_low_amplitude_noise_not_enhanced")

    # Test all configured device dimensions without assuming the panel is square.
    src = rng.integers(0, 256, (1001, 801, 3), dtype=np.uint8)
    for size in [(200, 200), (240, 240), (400, 400), (480, 720), (680, 960), (528, 768)]:
        actual = native(src, size)
        assert actual.shape == (size[1], size[0], 3)
    record("all_six_device_resolutions")

    dummy = np.zeros((4, 4, 4), dtype=np.uint8)
    p = dummy.ctypes.data_as(ptr)
    assert lib.XTPhotoResampleRGBA(None, 4, 4, 16, p, 4, 4, 16, .65) == 0
    assert lib.XTPhotoResampleRGBA(p, 4, 4, 15, p, 4, 4, 16, .65) == 0
    assert lib.XTPhotoEnhanceRGBA(p, 4, 4, 16, float("nan")) == 0
    record("invalid_inputs_rejected")

    # Keep photo parity checks active on a fresh clone without generated reports.
    for name, image in list(fixtures())[:4]:
        rgb = np.array(image)
        for size in [200, 400]:
            expected = np.array(photo_resize(image, (size, size)))
            actual = native(rgb, (size, size))
            error = int(np.abs(actual.astype(int) - expected.astype(int)).max())
            assert error <= 1
        record(f"photo_model_parity_{name}", max_channel_error=error)

    src = rng.integers(0, 256, (3000, 4000, 3), dtype=np.uint8)
    start = time.perf_counter()
    native(src, (400, 400))
    record("12mp_desktop_timing", seconds=round(time.perf_counter() - start, 3),
           note="Windows desktop only; not an iPhone benchmark")

    output = ROOT / "results" / "native_tests.json"
    output.parent.mkdir(exist_ok=True)
    output.write_text(json.dumps(records, indent=2), encoding="utf-8")
    print(f"{len(records)} checks passed", flush=True)


if __name__ == "__main__":
    main()
