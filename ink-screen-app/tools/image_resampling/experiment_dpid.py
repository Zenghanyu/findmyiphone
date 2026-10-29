"""Sampling-stage DPID comparisons and actual final six-colour outputs."""
import argparse
import html
import json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from experiment import fixtures
from resample import photo_resize
from dpid import dpid,_area
import hink_model as hm

ROOT=Path(__file__).resolve().parent


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',type=Path)
    parser.add_argument('--output',type=Path,default=ROOT/'results/dpid240')
    args=parser.parse_args();args.output.mkdir(exist_ok=True,parents=True)
    cases=[(args.input.stem,Image.open(args.input).convert('RGB'))] if args.input else list(fixtures())
    sections=[];metrics=[];font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
    for name,image in cases:
        side=min(image.size);x=(image.width-side)//2;y=(image.height-side)//2
        source=image.crop((x,y,x+side,y+side));rgb=np.asarray(source)
        source.save(args.output/f'{name}_source.png')
        area=np.floor(_area(rgb,240,240)+.5).astype(np.uint8)
        variants=[('area','面积平均',area,0),
                  ('lanczos','上一版 Lanczos',np.asarray(photo_resize(source,(240,240),0)),.8),
                  ('dpid_soft','DPID 温和对照',dpid(rgb,(240,240),.75,16,.65),0),
                  ('dpid_aggressive','DPID 激进（当前）',dpid(rgb,(240,240)),0)]
        sheet=Image.new('RGB',(4*320,1010),'#f4f5f7');draw=ImageDraw.Draw(sheet);cards=[]
        for i,(key,title,sampled,detail) in enumerate(variants):
            codes=hm.quantize(sampled,detail=detail)
            physical=hm.preview(codes)
            im=Image.fromarray(sampled);out=Image.fromarray(physical)
            im.save(args.output/f'{name}_{key}_rgb.png');out.save(args.output/f'{name}_{key}_preview.png')
            Image.fromarray(hm.preview(codes,False)).save(args.output/f'{name}_{key}_markers.png')
            np.save(args.output/f'{name}_{key}_indices.npy',codes)
            draw.text((i*320+8,10),title,font=font,fill='#172033')
            draw.text((i*320+8,36),'采样结果 RGB',font=font,fill='#45536a')
            sheet.paste(im.resize((300,300),Image.Resampling.NEAREST),(i*320+8,65))
            draw.text((i*320+8,379),'六色标称预览',font=font,fill='#45536a')
            sheet.paste(out.resize((300,300),Image.Resampling.NEAREST),(i*320+8,408))
            roi=(0,105,120,225) if name=='chelsea' else (60,60,180,180)
            draw.text((i*320+8,721),'六色局部像素放大',font=font,fill='#45536a')
            sheet.paste(out.crop(roi).resize((240,240),Image.Resampling.NEAREST),(i*320+8,752))
            metrics.append({'case':name,'variant':key,'max_change_vs_area':int(abs(sampled.astype(int)-area.astype(int)).max()),
                            'mean_change_vs_area':float(abs(sampled.astype(int)-area.astype(int)).mean()),
                            'valid_codes':sorted(int(v) for v in np.unique(codes)),
                            'post_Lstar_strength':detail})
            cards.append(f'<figure><figcaption>{title}</figcaption><img src="{name}_{key}_rgb.png"><img src="{name}_{key}_preview.png"></figure>')
        sheet.save(args.output/f'{name}_comparison.png')
        sections.append(f'<h2>{html.escape(name)}</h2><div class="row">'+''.join(cards)+f'</div><img class="sheet" src="{name}_comparison.png">')
        print(name,'done',flush=True)
    (args.output/'metrics.json').write_text(json.dumps(metrics,ensure_ascii=False,indent=2),encoding='utf-8')
    (args.output/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>DPID 降采样对照</title>
<style>body{font:16px system-ui;background:#fafbfc;color:#172033;margin:24px}.row{display:flex;gap:12px;overflow:auto}figure{margin:8px}figure img{display:block;width:240px;height:240px;margin-top:12px}img{image-rendering:pixelated}.sheet{max-width:1280px;width:100%}h2{margin-top:40px}</style>
<h1>在降采样时保留对比度：240×240</h1><p>DPID 风格面积覆盖逆双边实现。激进参数：指数 1.5、最大权重比 32、混合 90%、噪声底 2/255；温和对照：0.75、16、65%。权重来自源图与邻域参考的颜色差，非缩图后锐化。两种 DPID 不叠加后续 L* 锐化。</p>
<p>上排 RGB，下排最终六色；六色采用相同标称 Lab/XYZ 模型和边缘扩散。Lab 暂假设 D65/2°，非实测校色。面积与 Lanczos 均是实验对照，不是闭源 SDK 复现。激进增强允许纹理变粗、噪点更明显、细线变宽及局部明暗变化。</p>'''+''.join(sections),encoding='utf-8')


if __name__=='__main__':main()
