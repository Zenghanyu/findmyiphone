"""Generate local, reproducible comparisons; does not fetch photos from the web."""
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from skimage import data
from scipy.ndimage import convolve

from resample import legacy_resize, photo_resize


ROOT = Path(__file__).resolve().parent


def fixtures():
    for name in ["astronaut", "chelsea", "coffee", "motorcycle_left"]:
        p = Path(data.data_dir) / f"{name}.png"
        image = Image.open(p).convert("RGB")
        side = min(image.size)
        left, top = (image.width - side) // 2, (image.height - side) // 2
        yield name, image.crop((left, top, left + side, top + side))
    image = Image.new("RGB", (1600, 1600), (210, 210, 210))
    draw = ImageDraw.Draw(image)
    for i, width in enumerate([1, 2, 3, 4, 6, 8, 12]):
        y = 90 + i * 95
        draw.line((80, y, 1520, y + 340), fill=(45, 45, 45), width=width)
        draw.line((80, 950 + i * 50, 1520, 950 + i * 50), fill=(55, 55, 55), width=width)
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 52)
    draw.text((80, 1420), "Thin edges 1/2/3/4/6/8/12 px", fill=(50, 50, 50), font=font)
    yield "thin_lines", image


def gradient(rgb):
    y = np.asarray(rgb, float) @ [0.2126, 0.7152, 0.0722]
    gx = convolve(y, np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]]) / 8, mode="nearest")
    gy = convolve(y, np.array([[-1, -2, -1], [0, 0, 0], [1, 2, 1]]) / 8, mode="nearest")
    return np.hypot(gx, gy)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, help="Optional local photo")
    parser.add_argument("--output", type=Path, default=ROOT / "results")
    parser.add_argument("--view-width", type=float, default=350)
    parser.add_argument("--screen-scale", type=float, default=2)
    parser.add_argument("--crop", type=float, nargs=4, default=(0, 0, 1, 1), metavar=("X", "Y", "W", "H"),
                        help="Normalized source crop for both pipelines")
    args = parser.parse_args()
    out = args.output
    out.mkdir(exist_ok=True, parents=True)
    cases = [(args.input.stem, Image.open(args.input).convert("RGB"))] if args.input else list(fixtures())
    report, sections = [], []
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 20)
    crop = tuple(args.crop)
    x, y, cw, ch = crop
    if x < 0 or y < 0 or cw <= 0 or ch <= 0 or x + cw > 1 or y + ch > 1:
        parser.error("--crop must be a nonempty normalized rectangle within the image")
    for name, original in cases:
        image = original.crop((round(x * original.width), round(y * original.height),
                               round((x + cw) * original.width), round((y + ch) * original.height)))
        image.save(out / f"{name}_source.png")
        for size in [200, 400]:
            target = (size, size)
            legacy_options = {"view_width": args.view_width, "screen_scale": args.screen_scale, "crop": crop}
            variants = {"old_bilinear": legacy_resize(original, target, **legacy_options),
                        "old_bicubic": legacy_resize(original, target, interpolation="bicubic", **legacy_options),
                        "old_lanczos": legacy_resize(original, target, interpolation="lanczos", **legacy_options),
                        "direct_lanczos": photo_resize(image, target, strength=0),
                        "photo_detail": photo_resize(image, target)}
            base = np.asarray(variants["direct_lanczos"])
            mask = gradient(base) > 12
            metrics = {}
            cards = []
            sheet = Image.new("RGB", (5 * 320, 680), "#f4f5f7")
            draw = ImageDraw.Draw(sheet)
            for i, (key, result) in enumerate(variants.items()):
                path = f"{name}_{size}_{key}.png"
                result.save(out / path)
                # Output pixel grid is shown with nearest-neighbour zoom, never smoothing.
                sheet.paste(result.resize((300, 300), Image.Resampling.NEAREST), (i * 320 + 10, 45))
                detail_crop = result.crop((round(size * .25), round(size * .25), round(size * .625), round(size * .625)))
                sheet.paste(detail_crop.resize((300, 300), Image.Resampling.NEAREST), (i * 320 + 10, 365))
                draw.text((i * 320 + 10, 12), key, fill="#172033", font=font)
                g = gradient(result)
                metrics[key] = {"mean_edge_gradient": round(float(g[mask].mean()), 4) if mask.any() else 0}
                cards.append(f'<div><b>{key}</b><img src="{path}" width="{size}" height="{size}"></div>')
            sheet.save(out / f"{name}_{size}_comparison.png")
            delta = np.abs(np.asarray(variants["photo_detail"], int) - base.astype(int))
            report.append({"image": name, "source_size": image.size, "target": size,
                           "legacy_view_width": args.view_width, "legacy_screen_scale": args.screen_scale, "crop": crop,
                           "metrics": metrics, "max_detail_adjustment": int(delta.max())})
            sections.append(f'<h2>{html.escape(name)} / {size}x{size}</h2><div class="row">{"".join(cards)}</div>'
                            f'<p>Top: native output pixels. Below: nearest-neighbour enlarged crops.</p>'
                            f'<img class="sheet" src="{name}_{size}_comparison.png">')
    (out / "metrics.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    (out / "index.html").write_text('''<!doctype html><meta charset="utf-8"><title>Photo resampling comparison</title>
<style>body{font:15px system-ui;max-width:1680px;margin:28px auto;padding:0 20px;color:#172033;background:#fafbfc}
.row{display:flex;gap:20px;overflow:auto}.row div{display:flex;flex-direction:column;gap:12px}img{image-rendering:pixelated}.sheet{max-width:100%}h2{margin-top:45px}</style>
<h1>Photo downsampling: source pipeline vs edge-preserving proposal</h1>
<p>The three old variants are interpolation hypotheses, not captured UIKit output. All use a 350-point view,
2x screenshot. Partial crops use the old one-pixel height subtraction; full-bounds crops skip it, matching the source code. The proposed method uses the source photo directly,
antialiased Lanczos-3 with footprint bounds, then optional bounded luminance enhancement. No device SDK dithering is simulated.</p>
<p>Edge gradient is a contrast diagnostic, not a percentage of information retained or a perceptual quality score.</p>
''' + f'<p>Model parameters: view width={args.view_width:g} pt, scale={args.screen_scale:g}, normalized crop={crop}.</p>'
        + "\n".join(sections), encoding="utf-8")
    print(json.dumps({"cases": len(report), "output": str(out / "index.html")}, indent=2))


if __name__ == "__main__":
    main()
