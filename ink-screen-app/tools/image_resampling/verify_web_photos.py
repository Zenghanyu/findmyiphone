"""Replay downloaded photos against the saved, reviewed DPID comparison.

Runs the actual App C cores. Does not regenerate the expected image files.
Requires fetch_picsum_photos.py and compare_web_photos.py outputs locally.
"""
import hashlib
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageCms, ImageOps

from test_dpid import load_native, native
from test_hink import load_native as load_ink, native as ink_native, render


ROOT = Path(__file__).resolve().parent
SOURCES = ROOT / "web_sources"
EXPECTED = ROOT / "results/web_photos"


def main():
    lib = load_native()
    ink = load_ink()
    records = []
    for meta in json.loads((EXPECTED / "manifest.json").read_text(encoding="utf-8")):
        source = SOURCES / meta["file"]
        assert hashlib.sha256(source.read_bytes()).hexdigest() == meta["sha256"], source
        with Image.open(source) as raw:
            image = ImageOps.exif_transpose(raw)
            icc = image.info.get("icc_profile")
            if icc:
                image = ImageCms.profileToProfile(
                    image, ImageCms.ImageCmsProfile(io.BytesIO(icc)),
                    ImageCms.createProfile("sRGB"), outputMode="RGB")
            else:
                image = image.convert("RGB")
            source_rgb = np.asarray(image.crop(tuple(meta["crop_box"])))

        sampled = native(lib, source_rgb, (240, 240))
        codes = ink_native(ink, sampled, detail=0)
        prefix = EXPECTED / f'{meta["id"]}_dpid'
        expected_rgb = np.asarray(Image.open(str(prefix) + "_rgb.png").convert("RGB"))
        expected_codes = np.load(str(prefix) + "_codes.npy", allow_pickle=False)
        assert np.array_equal(sampled, expected_rgb), f'RGB changed: {meta["id"]}'
        assert np.array_equal(codes, expected_codes), f'Indices changed: {meta["id"]}'
        for stage, physical in [("preview", True), ("markers", False)]:
            expected_image = np.asarray(Image.open(str(prefix) + f"_{stage}.png").convert("RGB"))
            assert np.array_equal(render(ink, codes, physical=physical), expected_image), (
                f'{stage} changed: {meta["id"]}')
        records.append({"id": meta["id"], "passed": True,
                        "rgb_equal": True, "indices_equal": True,
                        "nominal_preview_equal": True, "upload_markers_equal": True})
        print(f'Photo {meta["id"]}: RGB / six-colour indices / preview / markers PASS', flush=True)

    assert len(records) == 8
    (EXPECTED / "verification.json").write_text(
        json.dumps(records, indent=2), encoding="utf-8")
    print("8 saved online-photo comparisons match the current App C cores exactly", flush=True)


if __name__ == "__main__":
    main()
