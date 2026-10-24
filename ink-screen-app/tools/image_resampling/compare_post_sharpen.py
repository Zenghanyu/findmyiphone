"""Isolate the old 0.8 L* post-sharpening on identical aggressive DPID input.

Generates comparison artifacts only; never edits App settings or source files.
"""
import base64
import hashlib
import html
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from compare_web_photos import LABELS
from hink_model import MATRIX
from test_hink import load_native, native, render

ROOT = Path(__file__).resolve().parent
INPUT = ROOT / "results/web_photos"
OUTPUT = ROOT / "results/dpid_post_sharpen"
VERSIONS = [("off", 0, "关闭二次锐化 · 当前 App"), ("on", .8, "开启二次锐化 · 强度 0.8")]
ROIS = {"1025": (70, 20, 170, 120), "1005": (80, 30, 180, 130),
        "1011": (80, 70, 180, 170), "1015": (10, 130, 110, 230),
        "1039": (30, 10, 130, 110), "1043": (100, 40, 200, 140),
        "106": (65, 35, 165, 135), "164": (50, 25, 150, 125)}


def embedded(image):
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode("ascii")


def xyz_preview(xyz):
    linear = xyz @ np.linalg.inv(MATRIX).T
    srgb = np.where(linear <= .0031308, linear * 12.92,
                    1.055 * np.maximum(linear, 0) ** (1 / 2.4) - .055)
    return Image.fromarray(np.floor(np.clip(srgb, 0, 1) * 255 + .5).astype(np.uint8))


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    lib = load_native()
    font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 20)
    small = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 17)
    manifests = json.loads((INPUT / "manifest.json").read_text(encoding="utf-8"))
    sections, records, examples = [], [], {}
    for meta in manifests:
        key, title = meta["id"], LABELS[meta["id"]]
        path = INPUT / f"{key}_dpid_rgb.png"
        rgb = np.asarray(Image.open(path).convert("RGB"))
        assert rgb.shape == (240, 240, 3)
        images, codes, guides = {}, {}, {}
        for version, strength, _ in VERSIONS:
            target, lab = native(lib, rgb, detail=strength, prepared=True)
            index = native(lib, rgb, detail=strength, edge=.55, dither=True)
            assert set(np.unique(index)).issubset({0, 1, 2, 3, 5, 6})
            guides[version], codes[version] = lab, index
            images[version] = {"continuous": xyz_preview(target),
                               "preview": Image.fromarray(render(lib, index))}
            for stage, im in images[version].items():
                im.save(OUTPUT / f"{key}_{version}_{stage}.png")
            np.save(OUTPUT / f"{key}_{version}_codes.npy", index)
            Image.fromarray(render(lib, index, physical=False)).save(
                OUTPUT / f"{key}_{version}_markers.png")

        # Current-App branch must reproduce the previously reviewed comparison.
        assert np.array_equal(codes["off"], np.load(INPUT / f"{key}_dpid_codes.npy"))
        assert np.array_equal(np.asarray(images["off"]["preview"]),
                              np.asarray(Image.open(INPUT / f"{key}_dpid_preview.png")))
        assert np.array_equal(guides["off"][..., 1:], guides["on"][..., 1:])
        delta = guides["on"][..., 0] - guides["off"][..., 0]
        assert np.max(np.abs(delta)) <= 2 + 1e-9
        record = {"id": key, "title": title, "input_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                  "strengths": [0, .8], "edge_protection": .55, "dither": True,
                  "mean_abs_Lstar_delta": float(np.mean(np.abs(delta))),
                  "max_abs_Lstar_delta": float(np.max(np.abs(delta))),
                  "six_colour_index_changed_fraction": float(np.mean(codes["off"] != codes["on"])),
                  "off_matches_current_app_comparison": True, "roi": ROIS[key]}
        records.append(record)
        examples[key] = images

        rows = []
        for stage, label in [("preview", "最终六色 · 标称预览"),
                              ("continuous", "量化前连续色 · 已映射面板色域")]:
            rows.append("<h3>" + label + '</h3><div class="pair">' + "".join(
                '<figure><figcaption>' + name + '</figcaption><img class="pixels" src="' +
                embedded(images[version][stage]) + '"></figure>' for version, _, name in VERSIONS) + "</div>")
        roi = ROIS[key]
        rows.append('<details open><summary>同一区域六色局部 · 4倍放大</summary><div class="pair">' + "".join(
            '<figure><figcaption>' + name + '</figcaption><img class="crop" src="' +
            embedded(images[version]["preview"].crop(roi)) + '"></figure>'
            for version, _, name in VERSIONS) + "</div></details>")
        source = embedded(Image.open(INPUT / f"{key}_source.jpg"))
        off, on = (embedded(images[v]["preview"]) for v in ["off", "on"])
        toggle = '<details><summary>原位切换：便于看细小变化</summary><button type="button" onclick="flip(this)">当前：关闭；点击开启</button><div><img class="pixels toggle" data-off="' + off + '" data-on="' + on + '" src="' + off + '"></div></details>'
        sections.append(f'<section id="p{key}"><h2>{title}</h2><p>作者：{html.escape(meta["author"])} · <a href="{html.escape(meta["url"])}">照片来源</a>。锐化对输入 L* 的平均绝对改动 {record["mean_abs_Lstar_delta"]:.3f}，最大 {record["max_abs_Lstar_delta"]:.3f}。</p><details><summary>查看原图裁剪</summary><img class="source" src="{source}"></details>' + "".join(rows) + toggle + "</section>")

        sheet = Image.new("RGB", (1010, 1030), "#f5f7fa")
        draw = ImageDraw.Draw(sheet)
        draw.text((15, 8), title + " / 同一 DPID 输入 / 最终六色", font=font, fill="#172033")
        for col, (version, _, name) in enumerate(VERSIONS):
            x = 15 + col * 500
            draw.text((x, 48), name, font=font, fill="#172033")
            sheet.paste(images[version]["preview"].resize((480, 480), Image.Resampling.NEAREST), (x, 86))
            draw.text((x, 587), "局部 4倍放大（同一区域）", font=small, fill="#45536a")
            sheet.paste(images[version]["preview"].crop(roi).resize((400, 400), Image.Resampling.NEAREST), (x, 620))
        sheet.save(OUTPUT / f"{key}_comparison.png")
        print(key, "PASS", f'mean |dL*|={record["mean_abs_Lstar_delta"]:.3f}', flush=True)

    # Compact final-output montage; integer magnification prevents smooth scaling.
    selected = ["164", "106", "1005"]
    montage = Image.new("RGB", (1010, 1690), "#f5f7fa")
    draw = ImageDraw.Draw(montage)
    for col, (_, _, name) in enumerate(VERSIONS):
        draw.text((15 + 500 * col, 10), name, font=font, fill="#172033")
    for row, key in enumerate(selected):
        y = 60 + row * 540
        draw.text((15, y), LABELS[key] + " · 六色标称预览", font=font, fill="#172033")
        for col, (version, _, _) in enumerate(VERSIONS):
            montage.paste(examples[key][version]["preview"].resize((480, 480), Image.Resampling.NEAREST),
                          (15 + 500 * col, y + 35))
    montage.save(OUTPUT / "selected_comparison.png")
    (OUTPUT / "metrics.json").write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
    header = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>DPID 二次锐化开关对照</title>
<style>body{font:16px/1.7 system-ui;max-width:1100px;margin:25px auto;padding:0 20px;background:#f5f7fa;color:#172033}section{background:white;padding:22px;margin:24px 0;border-radius:12px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px;overflow:auto}figure{margin:0;min-width:240px}figcaption{font-weight:600;margin:8px 0}.pixels{width:480px;max-width:100%;image-rendering:pixelated}.crop{width:400px;max-width:100%;image-rendering:pixelated}.source{width:600px;max-width:100%}summary,button{cursor:pointer}summary{margin:18px 0}button{padding:8px 14px}nav a{display:inline-block;margin:5px 15px 5px 0}</style>
<h1>同一 DPID 输入：二次锐化关闭 vs 开启</h1>
<p><b>左：关闭（当前 App）；右：开启原来的 0.8 强度 L* 锐化。</b>两边均使用同一张激进 DPID 240×240 结果。唯一变化是六色转换前的 L* 锐化强度，色板、色域映射、边缘扩散 0.55、扫描顺序均一致。不是把原 Lanczos 与 DPID 混在一起比较。</p>
<p>这项后处理只在低分辨率图上调整 L*，单像素最多 ±2 L*，保留 a*/b*；0.8 是算法强度，不能理解为对比度提高80%。图中“量化前连续色”由实际 C 核心的面板色域映射结果转成 sRGB，便于区分锐化变化与抖动变化。</p>
<p>最终六色为面板标称 Lab 暂按 D65/2° 换算的仿真，非实屏照片。误差扩散会让小幅输入变化重排较远处的色点；色点变化多不表示细节恢复多。可展开“原位切换”观察变化；全图为2倍、局部为4倍最近邻放大。</p>
<p><b>此次只生成对照，没有修改 App；当前仍关闭二次锐化，等待你决定。</b></p><nav>'''
    script = '''<script>function flip(b){const i=b.parentElement.querySelector('img.toggle');const on=i.dataset.state!=='on';i.dataset.state=on?'on':'off';i.src=on?i.dataset.on:i.dataset.off;b.textContent=on?'当前：开启；点击关闭':'当前：关闭；点击开启';}</script>'''
    (OUTPUT / "index.html").write_text(header + "".join(f'<a href="#p{m["id"]}">{LABELS[m["id"]]}</a>' for m in manifests) + "</nav>" + "".join(sections) + script + "</html>", encoding="utf-8")
    print("Saved", OUTPUT, flush=True)


if __name__ == "__main__":
    main()
