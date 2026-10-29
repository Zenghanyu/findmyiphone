"""Compare actual App C pipelines using downloaded, attributed online photographs."""
import base64,html,io,json,hashlib
from pathlib import Path
import numpy as np
from PIL import Image,ImageOps,ImageCms,ImageDraw,ImageFont
from test_dpid import load_native,native
from test_hink import load_native as load_ink,native as ink_native,render
ROOT=Path(__file__).resolve().parent
SOURCES=ROOT/'web_sources';OUT=ROOT/'results/web_photos'
LABELS={'1025':'狗的毛发与轮廓','1005':'人像发丝与衣物','1011':'人物与水面','1015':'山脊与峡湾','1039':'瀑布与岩石','1043':'树林与山地','106':'花朵与草叶','164':'城市与建筑'}
def embed(im):
 b=io.BytesIO();im.save(b,format='PNG');return 'data:image/png;base64,'+base64.b64encode(b.getvalue()).decode()
def main():
 OUT.mkdir(parents=True,exist_ok=True);lib=load_native();ink=load_ink();records=[];sections=[];montages=[]
 font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',19)
 for meta in json.loads((SOURCES/'manifest.json').read_text(encoding='utf-8')):
  key=meta['id'];title=LABELS[key];source=SOURCES/meta['file'];assert hashlib.sha256(source.read_bytes()).hexdigest()==meta['sha256']
  with Image.open(source) as raw:
   im=ImageOps.exif_transpose(raw);icc=im.info.get('icc_profile');color='embedded ICC converted to sRGB' if icc else 'no ICC; assumed sRGB'
   im=ImageCms.profileToProfile(im,ImageCms.ImageCmsProfile(io.BytesIO(icc)),ImageCms.createProfile('sRGB'),outputMode='RGB') if icc else im.convert('RGB')
   w,h=im.size;side=min(w,h);box=((w-side)//2,(h-side)//2,(w-side)//2+side,(h-side)//2+side);crop=im.crop(box);rgb=np.asarray(crop)
  orig=crop.copy();orig.thumbnail((600,600));orig.save(OUT/f'{key}_source.jpg',quality=95)
  outputs={};stats={}
  for name,is_dpid,detail in [('lanczos',False,.8),('dpid',True,0)]:
   sample=native(lib,rgb,(240,240),use_dpid=is_dpid);codes=ink_native(ink,sample,detail=detail)
   assert set(np.unique(codes)).issubset({0,1,2,3,5,6})
   outputs[name]={'rgb':Image.fromarray(sample),'preview':Image.fromarray(render(ink,codes))}
   np.save(OUT/f'{key}_{name}_codes.npy',codes)
   for stage,img in outputs[name].items():img.save(OUT/f'{key}_{name}_{stage}.png')
   Image.fromarray(render(ink,codes,physical=False)).save(OUT/f'{key}_{name}_markers.png')
   stats[name]={'black_fraction':float(np.mean(codes==0))}
  rows=[]
  for stage,label in [('rgb','仅采样 RGB · 未做后续 L* 增强'),('preview','完整流程 · 六色标称预览')]:
   rows.append('<h3>'+label+'</h3><div class="pair">'+''.join('<figure><figcaption>'+name+'</figcaption><img class="pixels" src="'+embed(outputs[k][stage])+'"></figure>' for k,name in [('lanczos','Lanczos'),('dpid','激进 DPID')])+'</div>')
  roi=(60,60,180,180)
  for stage,label in [('rgb','中心局部 RGB'),('preview','同一区域六色')]:
   rows.append('<details><summary>'+label+' · 4倍像素放大</summary><div class="pair">'+''.join('<figure><figcaption>'+name+'</figcaption><img class="pixels" src="'+embed(outputs[k][stage].crop(roi))+'"></figure>' for k,name in [('lanczos','Lanczos'),('dpid','激进 DPID')])+'</div></details>')
  sections.append(f'<section id="p{key}"><h2>{title}</h2><p>{w}×{h} → 居中 {side}×{side} → 240×240；作者：{html.escape(meta["author"])} · <a href="{html.escape(meta["url"])}">照片来源</a> · <a href="{html.escape(meta["download_url"])}">下载地址</a></p><details><summary>查看输入照片与裁剪</summary><img class="source" src="{embed(orig)}"></details>'+''.join(rows)+'</section>')
  sheet=Image.new('RGB',(1000,1100),'#f6f8fa');d=ImageDraw.Draw(sheet);d.text((16,8),title+' / 240×240',fill='#172033',font=font)
  for c,(k,label) in enumerate([('lanczos','Lanczos'),('dpid','激进 DPID')]):
   x=10+500*c;d.text((x,40),label,fill='#172033',font=font)
   for stage,y,label2 in [('rgb',100,'采样 RGB'),('preview',620,'最终六色（标称预览）')]:
    d.text((x,y-29),label2,font=font,fill='#45536a');sheet.paste(outputs[k][stage].resize((480,480),Image.Resampling.NEAREST),(x,y))
  sheet.save(OUT/f'{key}_comparison.png')
  montages.append((key,title,outputs));records.append(dict(meta,color_handling=color,crop_box=box,output_size=[240,240],diagnostics=stats))
  print('Processed',key,title,flush=True)
 (OUT/'manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
 montage=Image.new('RGB',(1240,len(montages)*290+65),'#f6f8fa');d=ImageDraw.Draw(montage)
 for x,label in [(10,'输入照片（仅作参考）'),(420,'Lanczos · 最终六色'),(830,'激进 DPID · 最终六色')]:d.text((x,10),label,font=font,fill='#172033')
 for n,(key,title,outputs) in enumerate(montages):
  y=65+n*290;d.text((10,y),title,font=font,fill='#172033');src=Image.open(OUT/f'{key}_source.jpg');src.thumbnail((240,240));montage.paste(src,(10,y+30))
  for x,k in [(420,'lanczos'),(830,'dpid')]:montage.paste(outputs[k]['preview'],(x,y+30))
 montage.save(OUT/'overview.png')
 (OUT/'index.html').write_text('''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>网上照片：Lanczos 与激进 DPID</title><style>body{font:16px/1.7 system-ui;max-width:1100px;margin:30px auto;padding:0 20px;background:#f6f8fa;color:#172033}section{padding:22px;background:white;margin:25px 0;border-radius:12px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}figure{margin:0}figcaption{font-weight:bold}.pixels{width:100%;max-width:480px;image-rendering:pixelated}.source{max-width:100%;width:600px}summary{cursor:pointer;margin:18px 0}nav a{display:inline-block;margin:5px 15px 5px 0}</style><h1>网上照片：Lanczos 与激进 DPID</h1><p>8 张新下载的公开照片；每张使用相同的原生像素居中正方形裁剪，直接执行 App 的 C 核心输出 240×240。RGB 行单独比较采样算法。最终六色行比较改动前的 Lanczos＋0.8 L* 增强与激进 DPID＋关闭后增强；色板、色域映射和误差扩散一致。</p><p>DPID：指数1.5、权重比上限32、混合90%、噪声底2/255。它是当前工程实现的 DPID 风格变体。高对比细节权重更大，也可能加粗线条、强化噪点、改变明暗和产生混叠。这里没有客观“保真率”或实屏评分。</p><p>六色按 HINK 240×240 面板标称 Lab 暂按 D65/2° 转换，仅为仿真预览，非实屏拍摄。照片由 Lorem Picsum 按目录原始尺寸交付，保留下载文件及 SHA256、作者和 Unsplash 来源；无法排除上游 JPEG 重编码。未核验额外再分发许可，不声称为 CC 图片。</p><p>页面大图采用最近邻放大；可展开输入照片、RGB 局部及六色局部。原生输出、精确色码和来源清单保存在同目录。</p><nav>'''+''.join(f'<a href="#p{k}">{LABELS[k]}</a>' for k,_,_ in montages)+'</nav>'+''.join(sections)+'</html>',encoding='utf-8')
 print('Saved',OUT,flush=True)
if __name__=='__main__':main()
