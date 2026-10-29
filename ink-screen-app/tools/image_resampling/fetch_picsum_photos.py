from pathlib import Path
import requests,concurrent.futures,json,hashlib,time
from PIL import Image,ImageOps,ImageDraw
ROOT=Path('tools/image_resampling/web_sources');ROOT.mkdir(parents=True,exist_ok=True)
def fetch(i):
 for trial in range(3):
  try:
   p=ROOT/f'picsum_{i}.jpg';m=ROOT/f'picsum_{i}.json'
   if m.exists() and p.exists():return json.loads(m.read_text())
   s=requests.Session();info=s.get(f'https://picsum.photos/id/{i}/info',timeout=(8,25));info.raise_for_status();meta=info.json()
   r=s.get(meta['download_url'],timeout=(8,60));r.raise_for_status();p.write_bytes(r.content)
   with Image.open(p) as im:assert im.size==(meta['width'],meta['height'])
   meta.update(file=p.name,sha256=hashlib.sha256(r.content).hexdigest(),resolved_download_url=r.url,downloaded_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),source_note='Lorem Picsum delivery at catalog native dimensions; upstream JPEG recompression cannot be excluded. Author and Unsplash source from Picsum API; no additional license verification.')
   m.write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8');print('SAVED',i,len(r.content),flush=True);return meta
  except Exception as e:print('RETRY',i,type(e).__name__,flush=True)
 return None
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:items=[x for x in ex.map(fetch,[1025,1005,1011,1015,1039,1043,106,164]) if x]
(ROOT/'manifest.json').write_text(json.dumps(items,ensure_ascii=False,indent=2),encoding='utf-8')
sheet=Image.new('RGB',(1200,600),'white');d=ImageDraw.Draw(sheet)
for n,m in enumerate(items):
 im=ImageOps.exif_transpose(Image.open(ROOT/m['file'])).convert('RGB');im.thumbnail((290,255));x=n%4*300;y=n//4*300;sheet.paste(im,(x,y+25));d.text((x+8,y+4),m['id']+' '+m['author'],fill='black')
sheet.save(ROOT/'contact_sheet.jpg')
