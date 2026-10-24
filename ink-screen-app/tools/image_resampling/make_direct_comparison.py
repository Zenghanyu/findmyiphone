"""Two-column comparison of the pre-DPID App path and aggressive DPID.

Reuses verified outputs; does not silently change the sampling/quantization.
"""
import argparse
import base64
import html
import io
import json
import statistics
import time
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parent
SOURCE=ROOT/'results/dpid240'
OUTPUT=ROOT/'results/dpid_vs_lanczos'
CASES=[('chelsea','猫毛与胡须',(0,100,120,220)),
       ('astronaut','人像与衣领',(40,20,160,140)),
       ('motorcycle_left','机械结构与斜边',(50,60,170,180)),
       ('coffee','杯口与细碎纹理',(40,70,160,190)),
       ('thin_lines','细线测试',(12,12,160,115))]
VERSIONS=[('lanczos','改动前：Lanczos'),('dpid_aggressive','激进 DPID')]


def embedded(image):
    buffer=io.BytesIO();image.save(buffer,format='PNG')
    return 'data:image/png;base64,'+base64.b64encode(buffer.getvalue()).decode('ascii')


def benchmark():
    from test_dpid import load_native,native
    from test_hink import load_native as load_ink,native as ink_native
    lib=load_native();ink=load_ink()
    rgb=np.random.default_rng(20261023).integers(0,256,(3000,4000,3),dtype=np.uint8)
    values={'lanczos':[],'dpid_aggressive':[]}
    # Identical source, helper buffers, output size and palette. Alternate order.
    for iteration in range(3):
        order=VERSIONS if iteration%2==0 else VERSIONS[::-1]
        for key,_ in order:
            start=time.perf_counter()
            sampled=native(lib,rgb,(240,240),padding=0,use_dpid=key!='lanczos')
            ink_native(ink,sampled,detail=.8 if key=='lanczos' else 0,padding=0)
            values[key].append(time.perf_counter()-start)
    return {'conditions':'Windows desktop, deterministic 12MP random RGB, 240x240, same helpers and six-colour conversion; includes buffer preparation/copies; not iPhone performance',
            'trials':values,'median_seconds':{key:statistics.median(v) for key,v in values.items()}}


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--benchmark',action='store_true');args=parser.parse_args()
    OUTPUT.mkdir(exist_ok=True,parents=True)
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',21)
    small=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',17)
    sections=[]
    for name,title,roi in CASES:
        # Native RGB and six-colour pixels are the saved verified outputs.
        images={key:{stage:Image.open(SOURCE/f'{name}_{key}_{stage}.png').convert('RGB')
                     for stage in ['rgb','preview']} for key,_ in VERSIONS}
        sheet=Image.new('RGB',(1016,1620),'#f4f5f7');draw=ImageDraw.Draw(sheet)
        draw.text((20,10),title+' / 240×240',font=font,fill='#172033')
        for col,(key,label) in enumerate(VERSIONS):
            x=20+col*500;draw.text((x,48),label,font=font,fill='#172033')
            for stage,y,label2 in [('rgb',105,'RGB 采样结果 · 2倍像素显示'),('preview',640,'最终六色 · 标称颜色预览')]:
                draw.text((x,y-27),label2,font=small,fill='#45536a')
                sheet.paste(images[key][stage].resize((480,480),Image.Resampling.NEAREST),(x,y))
            crop=images[key]['preview'].crop(roi)
            draw.text((x,1144),'六色局部 · 最近邻放大',font=small,fill='#45536a')
            factor=min(480//crop.width,420//crop.height)
            sheet.paste(crop.resize((crop.width*factor,crop.height*factor),Image.Resampling.NEAREST),(x,1180))
        sheet.save(OUTPUT/f'{name}_comparison.png')
        rows=[]
        for stage,label in [('rgb','RGB 采样结果'),('preview','最终六色（标称预览）')]:
            rows.append('<h3>'+label+'</h3><div class="pair">'+''.join(
                '<figure><figcaption>'+label2+'</figcaption><img width="240" height="240" src="'+embedded(images[key][stage])+'"></figure>'
                for key,label2 in VERSIONS)+'</div>')
        for stage,label in [('rgb','RGB 局部放大'),('preview','六色局部放大')]:
            rows.append('<h3>'+label+'</h3><div class="pair">'+''.join(
                '<figure><figcaption>'+label2+'</figcaption><img class="crop" src="'+embedded(images[key][stage].crop(roi))+'"></figure>'
                for key,label2 in VERSIONS)+'</div>')
        sections.append('<section id="'+name+'"><h2>'+html.escape(title)+'</h2>'+''.join(rows)+'</section>')
    # Compact, integer-pixel magnification of the thin structures for inline use.
    roi=CASES[-1][2];factor=3;w=(roi[2]-roi[0])*factor;h=(roi[3]-roi[1])*factor
    compact=Image.new('RGB',(2*w+60,2*h+150),'#f4f5f7');draw=ImageDraw.Draw(compact)
    for col,(key,label) in enumerate(VERSIONS):
        x=20+col*(w+20);draw.text((x,8),label,font=font,fill='#172033')
        for row,(stage,label2) in enumerate([('rgb','细线 RGB · 3倍像素放大'),('preview','最终六色 · 同一区域')]):
            y=64+row*(h+65);draw.text((x,y-28),label2,font=small,fill='#45536a')
            im=Image.open(SOURCE/f'thin_lines_{key}_{stage}.png').crop(roi)
            compact.paste(im.resize((w,h),Image.Resampling.NEAREST),(x,y))
    compact.save(OUTPUT/'thin_lines_detail.png')
    diagnostics=json.loads((SOURCE/'line_diagnostics.json').read_text())
    table=[]
    for width in [.25,.5,1,2]:
        a=next(r for r in diagnostics if r['target_line_width']==width and r['sampling']=='lanczos')
        b=next(r for r in diagnostics if r['target_line_width']==width and r['sampling']=='dpid')
        table.append(f"<tr><td>{width:g}px</td><td>{a['black_pixels_in_4px_corridor_per_row']:.3f}</td><td>{b['black_pixels_in_4px_corridor_per_row']:.3f}</td></tr>")
    timing=''
    if args.benchmark:
        result=benchmark();(OUTPUT/'benchmark.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
        a=result['median_seconds']['lanczos'];b=result['median_seconds']['dpid_aggressive']
        timing=f'<p>同批桌面参考：12MP → 240×240，加六色转换，交替运行各3次中位数：Lanczos {a:.3f}s，DPID {b:.3f}s。包含相同缓冲区准备与复制；随机RGB样例，不代表 iPhone 或真实照片耗时。</p>'
        print('Benchmark:',a,b,flush=True)
    (OUTPUT/'index.html').write_text('''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>Lanczos 与激进 DPID 直接对照</title>
<style>body{font:16px/1.7 system-ui,sans-serif;max-width:1100px;margin:30px auto;padding:0 20px;background:#f8fafc;color:#172033}h1{line-height:1.4}section{background:white;border:1px solid #dce2ea;border-radius:14px;margin:28px 0;padding:22px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px;overflow:auto}figure{margin:0;min-width:240px}figcaption{font-weight:600;margin-bottom:10px}img{image-rendering:pixelated}img.crop{width:100%;max-width:480px;height:auto}table{border-collapse:collapse}td,th{border:1px solid #cbd5e1;padding:8px 16px;text-align:left}nav a{display:inline-block;margin:4px 16px 4px 0}h3{margin-top:25px}</style>
<h1>改动前 Lanczos vs 激进 DPID</h1>
<p><b>这里的“当前算法对比”以改动前的 App 照片流程为基准。</b>左侧是 Lanczos 缩图＋原有 0.8 L* 增强，右侧是激进 DPID 缩图＋关闭后续 L* 锐化。两者使用同一源图、同一裁剪、240×240 分辨率，以及相同的面板色板和边缘扩散。</p>
<p>RGB 行只比较采样结果（尚未做 L* 后增强）；最终六色行比较各自完整流程。DPID 参数为指数 1.5、权重比上限32、自适应混合90%、2/255噪声底。五组结果均来自已验证的输出文件，本报告不修改 App。</p>
<p><b>主要取舍：</b>DPID 提高细线和高对比纹理的贡献，也可能加粗结构、强化噪点、改变局部明暗和增加混叠。六色是厂家标称 Lab 暂按 D65/2° 换算的预览，非实屏照片；参考流程也不是闭源 SDK 的精确复现。</p>'''+timing+
        '<nav>'+''.join(f'<a href="#{name}">{title}</a>' for name,title,_ in CASES)+'</nav>'+
        '<h2>细线定量诊断</h2><p>白底暗线：线条附近4px走廊每行黑像素数。数值变大表示线条贡献增加，也可能意味着加粗；不是信息保留率。</p><table><tr><th>目标线宽</th><th>Lanczos</th><th>激进DPID</th></tr>'+''.join(table)+'</table>'+
        ''.join(sections)+'</html>',encoding='utf-8')
    print('Saved',OUTPUT,flush=True)


if __name__=='__main__':main()
