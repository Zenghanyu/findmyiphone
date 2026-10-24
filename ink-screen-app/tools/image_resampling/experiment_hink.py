"""Compare final six-colour outputs; references do not reproduce SDK dithering."""
import argparse
import html
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter
from experiment import fixtures
from resample import photo_resize
import hink_model as hm

ROOT=Path(__file__).resolve().parent


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',type=Path)
    parser.add_argument('--output',type=Path,default=ROOT/'results/hink240')
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    cases=[(args.input.stem,Image.open(args.input).convert('RGB'))] if args.input else list(fixtures())
    sections=[]
    metrics=[]
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
    for name,image in cases:
        # Same centre square for each candidate, no screenshot resizing.
        s=min(image.size); x=(image.width-s)//2; y=(image.height-s)//2
        source=image.crop((x,y,x+s,y+s))
        rgb=np.asarray(photo_resize(source,(240,240),strength=0))
        prior_rgb=np.asarray(photo_resize(source,(240,240),strength=.65))
        ideal_xyz=hm.rgb_to_xyz(hm.MARKERS)
        ideal_lab=hm.xyz_to_lab(ideal_xyz)
        target,guide=hm.prepare(rgb,0)
        proposed,enhanced=hm.prepare(rgb,.8)
        candidates={
            '理想RGB色板参考':hm.diffuse(hm.rgb_to_xyz(prior_rgb),hm.xyz_to_lab(hm.rgb_to_xyz(prior_rgb)),
                                        True,0,ideal_xyz,ideal_lab),
            '普通扩散（标称色板）':hm.diffuse(target,guide,True,0),
            '面积采样＋边缘保护':hm.quantize(np.asarray(source.resize((240,240),Image.Resampling.BOX))),
            '轮廓增强＋边缘保护':hm.diffuse(proposed,enhanced,True,.55),
        }
        sheet=Image.new('RGB',(320*5,680),'#f4f5f7')
        draw=ImageDraw.Draw(sheet)
        ref=Image.fromarray(rgb)
        for i,(title,im) in enumerate([('采样输入（RGB）',ref)]+[(k,Image.fromarray(hm.preview(v))) for k,v in candidates.items()]):
            draw.text((i*320+8,10),title,font=font,fill='#172033')
            sheet.paste(im.resize((300,300),Image.Resampling.NEAREST),(i*320+8,42))
            sheet.paste(im.crop((65,60,165,160)).resize((300,300),Image.Resampling.NEAREST),(i*320+8,365))
        sheet.save(args.output/f'{name}_comparison.png')
        cards=[]
        for n,(title,codes) in enumerate(candidates.items()):
            Image.fromarray(hm.preview(codes)).save(args.output/f'{name}_{n}_preview.png')
            Image.fromarray(hm.preview(codes,False)).save(args.output/f'{name}_{n}_markers.png')
            np.save(args.output/f'{name}_{n}_indices.npy',codes)
            xyz_lut=np.zeros((7,3));xyz_lut[hm.CODES]=hm.XYZ
            reconstructed=xyz_lut[codes]
            # 1px Gaussian is a diagnostic viewing scale, NOT measured panel optics.
            observed=gaussian_filter(reconstructed,(1,1,0))
            reference=gaussian_filter(target,(1,1,0))
            error=np.linalg.norm(hm.xyz_to_lab(observed)-hm.xyz_to_lab(reference),axis=-1)
            record={'case':name,'variant':title,'diagnostic_mean_deltaE76_sigma1':float(error.mean()),
                    'valid_codes':sorted(int(c) for c in np.unique(codes))}
            metrics.append(record)
            cards.append(f'<figure><figcaption>{title}</figcaption><img src="{name}_{n}_preview.png" width="240" height="240"></figure>')
            print(record,flush=True)
        sections.append(f'<h2>{html.escape(name)}</h2><div class="row">'+''.join(cards)+f'</div><img class="sheet" src="{name}_comparison.png">')
    (args.output/'metrics.json').write_text(json.dumps(metrics,ensure_ascii=False,indent=2),encoding='utf-8')
    (args.output/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>HINK 240 六色照片比较</title>
<style>body{font:16px system-ui;margin:30px;background:#fafbfc;color:#172033}.row{display:flex;gap:16px}figure{margin:8px}img{image-rendering:pixelated}.sheet{max-width:1600px;width:100%}h2{margin-top:40px}</style>
<h1>240×240 六色最终输出</h1><p>标称 Lab 暂按 D65/2° 换算；预览不是实测校色。所有结果只使用六种色态。理想 RGB 色板与普通扩散均为开放参考算法，不代表闭源 SDK。</p>
<p>每组第一行含原尺寸预览，下方为像素放大和细节。物理有效区域 27×27mm；浏览器无法保证显示器上的实际毫米尺寸。诊断指标的 1px 高斯仅为统一观察尺度，不是硬件光学模型；数值不等于细节保留率。</p>'''+''.join(sections),encoding='utf-8')


if __name__=='__main__':main()
