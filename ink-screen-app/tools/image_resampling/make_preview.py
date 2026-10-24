"""Small, clearly labelled visual for reviewing the default photo proposal."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parent / "results"
font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 22)
small = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 17)
sheet = Image.new("RGB", (960, 720), "#f4f5f7")
draw = ImageDraw.Draw(sheet)
for i, (name, title) in enumerate([
    ("old_bicubic", "旧流程模型（双三次假设）"),
    ("direct_lanczos", "原图直接 Lanczos-3"),
    ("photo_detail", "加受限亮度细节增强"),
]):
    photo = Image.open(root / f"chelsea_200_{name}.png")
    draw.text((i * 320 + 10, 12), title, font=font, fill="#172033")
    sheet.paste(photo.resize((300, 300), Image.Resampling.NEAREST), (i * 320 + 10, 55))
    detail = photo.crop((50, 50, 125, 125))
    sheet.paste(detail.resize((300, 300), Image.Resampling.NEAREST), (i * 320 + 10, 375))
draw.text((12, 688), "200×200 输出；下排为像素放大。左列非 UIKit 实测，未经过 SDK 抖点。", font=small, fill="#475467")
sheet.save(root / "preview.png")
print(root / "preview.png")
