"""Compact actual-output comparison for the App file preview."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont

root=Path(__file__).resolve().parent/'results/dpid240'
sheet=Image.new('RGB',(760,854),'#f4f5f7')
draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',19)
small=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',16)
for i,(key,title) in enumerate([('lanczos','上一版 Lanczos'),('dpid_aggressive','激进 DPID（当前）')]):
    x=i*380+10
    draw.text((x,10),title,fill='#172033',font=font)
    draw.text((x,42),'RGB 采样结果',fill='#45536a',font=small)
    rgb=Image.open(root/f'chelsea_{key}_rgb.png')
    sheet.paste(rgb.resize((360,360),Image.Resampling.NEAREST),(x,70))
    draw.text((x,447),'最终六色（标称色彩预览）',fill='#45536a',font=small)
    physical=Image.open(root/f'chelsea_{key}_preview.png')
    sheet.paste(physical.resize((360,360),Image.Resampling.NEAREST),(x,475))
sheet.save(root/'preview.png')
