"""Execute actual App DPID C core; compare independent Python and six-colour paths."""
import ctypes as ct
from fractions import Fraction
import json
import os
import subprocess
import time
from pathlib import Path
import numpy as np
from PIL import Image
from dpid import dpid,_area
from experiment import fixtures
from resample import lanczos3
from test_hink import load_native as load_ink,native as ink_native
import hink_model as hm

ROOT=Path(__file__).resolve().parent
CORE=ROOT.parents[1]/'ios/BrushSDK/Core/Support/ImageDither/XTPhotoResampleCore.c'


def load_native():
    dll=ROOT/'.build/photo_dpid.dll';dll.parent.mkdir(exist_ok=True)
    subprocess.run([str(Path(os.environ.get('XT_ZIG', ROOT/'.runtime/ziglang/zig.exe'))),'cc','-std=c11','-O2','-Wall','-Wextra','-Werror',
                    '-shared','-Wl,--export-all-symbols',str(CORE),'-o',str(dll)],check=True)
    lib=ct.CDLL(str(dll));p=ct.POINTER(ct.c_uint8);s=ct.c_size_t
    lib.XTPhotoDPIDResampleRGBA.argtypes=[p,s,s,s,p,s,s,s,ct.c_double,ct.c_double,ct.c_double]
    lib.XTPhotoResampleRGBA.argtypes=[p,s,s,s,p,s,s,s,ct.c_double]
    return lib


def native(lib,rgb,size,exponent=1.5,ratio=32,blend=.9,padding=12,use_dpid=True):
    sh,sw,_=rgb.shape;dw,dh=size
    source=np.full((sh,sw*4+padding),93,dtype=np.uint8)
    source[:,:sw*4].reshape(sh,sw,4)[...,:3]=rgb
    source[:,:sw*4].reshape(sh,sw,4)[...,3]=255
    output=np.full((dh,dw*4+padding),91,dtype=np.uint8)
    before=source.copy();p=ct.POINTER(ct.c_uint8)
    if use_dpid:
        ok=lib.XTPhotoDPIDResampleRGBA(source.ctypes.data_as(p),sw,sh,source.strides[0],output.ctypes.data_as(p),
                                     dw,dh,output.strides[0],exponent,ratio,blend)
    else:
        ok=lib.XTPhotoResampleRGBA(source.ctypes.data_as(p),sw,sh,source.strides[0],output.ctypes.data_as(p),
                                 dw,dh,output.strides[0],0)
    assert ok==1
    assert np.array_equal(before,source),'Source overwritten'
    assert np.all(output[:,dw*4:]==91),'Output padding overwritten'
    rgba=output[:,:dw*4].reshape(dh,dw,4)
    assert np.all(rgba[...,3]==255)
    return rgba[...,:3].copy()


def exact_area(rgb,size):
    sh,sw,_=rgb.shape;dw,dh=size;result=np.empty((dh,dw,3),dtype=np.uint8)
    for y in range(dh):
        top,bottom=Fraction(y*sh,dh),Fraction((y+1)*sh,dh)
        for x in range(dw):
            left,right=Fraction(x*sw,dw),Fraction((x+1)*sw,dw)
            values=[Fraction(0)]*3
            for yy in range(sh):
                wy=max(Fraction(0),min(bottom,yy+1)-max(top,yy))
                for xx in range(sw):
                    w=wy*max(Fraction(0),min(right,xx+1)-max(left,xx))
                    for c in range(3):values[c]+=int(rgb[yy,xx,c])*w
            for c in range(3):
                v=values[c]/((right-left)*(bottom-top))+Fraction(1,2)
                result[y,x,c]=v.numerator//v.denominator
    return result


def main():
    lib=load_native();records=[];rng=np.random.default_rng(20261024)
    def record(name,**values):
        records.append({'test':name,'passed':True,**values});print(name,'PASS',values,flush=True)
    for sw,sh,dw,dh in [(97,83,29,31),(80,64,20,16),(1,43,1,13),(43,1,13,1),
                        (47,29,1,1),(1,1,1,1),(7,9,13,17),(33,35,33,35),(17,31,23,11)]:
        rgb=rng.integers(0,256,(sh,sw,3),dtype=np.uint8)
        expected=dpid(rgb,(dw,dh));actual=native(lib,rgb,(dw,dh))
        delta=int(np.max(abs(expected.astype(int)-actual.astype(int))))
        assert delta<=1
        record(f'python_native_{sw}x{sh}_to_{dw}x{dh}',max_channel_error=delta)
    rgb=rng.integers(0,256,(13,17,3),dtype=np.uint8);expected=exact_area(rgb,(7,5))
    for kwargs in [{'exponent':0},{'ratio':1},{'blend':0}]:
        assert np.array_equal(native(lib,rgb,(7,5),**kwargs),expected)
    record('disabled_adaptation_equals_exact_fractional_area_oracle')
    # Hand-computed inverse bilateral: one dark sample among 15 bright samples.
    rgb=np.full((4,4,3),240,dtype=np.uint8);rgb[0,0]=20
    adaptive=(15*240+32*20)/47
    expected=int(np.floor(.1*((15*240+20)/16)+.9*adaptive+.5))
    assert expected==104 and np.all(native(lib,rgb,(1,1))==expected)
    record('rare_detail_is_weighted_before_reduction',area_value=226,dpid_value=expected)
    for color in [(0,0,0),(255,255,255),(73,141,205),(255,0,0)]:
        rgb=np.full((97,103,3),color,dtype=np.uint8)
        assert np.all(native(lib,rgb,(29,31))==color)
    record('uniform_regions_and_pure_colours_unchanged')
    gray=rng.integers(127,130,(160,160,1),dtype=np.uint8)
    rgb=np.repeat(gray,3,axis=2)
    area=np.floor(_area(rgb,40,40)+.5).astype(np.uint8)
    assert np.array_equal(native(lib,rgb,(40,40)),area)
    record('two_unit_neutral_noise_not_amplified')
    yy,xx=np.indices((960,960));rgb=np.repeat((((xx+yy)%2)*255).astype(np.uint8)[...,None],3,axis=2)
    out=native(lib,rgb,(240,240))
    assert out.std()==0 and np.all(out==128)
    record('balanced_checkerboard_antialiasing')
    rgb=rng.integers(0,256,(43,51,3),dtype=np.uint8);out=native(lib,rgb,(17,13))
    for y in range(13):
        for x in range(17):
            region=rgb[int(np.floor(y*43/13)):int(np.ceil((y+1)*43/13)),
                       int(np.floor(x*51/17)):int(np.ceil((x+1)*51/17))]
            assert np.all(out[y,x]>=region.min((0,1))) and np.all(out[y,x]<=region.max((0,1)))
    record('no_new_colour_extrema_outside_source_footprint')
    p=ct.POINTER(ct.c_uint8);source=np.zeros((8,8,4),dtype=np.uint8);out=np.zeros((2,2,4),dtype=np.uint8)
    for exponent,ratio,blend in [(float('nan'),32,.9),(-1,32,.9),(5,32,.9),(1.5,.5,.9),(1.5,300,.9),(1.5,32,1.1)]:
        assert lib.XTPhotoDPIDResampleRGBA(source.ctypes.data_as(p),8,8,32,out.ctypes.data_as(p),2,2,8,exponent,ratio,blend)==0
    assert lib.XTPhotoDPIDResampleRGBA(None,8,8,32,out.ctypes.data_as(p),2,2,8,1.5,32,.9)==0
    assert lib.XTPhotoDPIDResampleRGBA(source.ctypes.data_as(p),8,8,31,out.ctypes.data_as(p),2,2,8,1.5,32,.9)==0
    record('bad_parameters_null_and_short_stride_rejected')
    ink=load_ink()
    for name,image in list(fixtures())[:4]:
        rgb=np.asarray(image)
        expected=dpid(rgb,(240,240));actual=native(lib,rgb,(240,240))
        assert np.array_equal(expected,actual)
        expected_codes=hm.quantize(expected,detail=0)
        actual_codes=ink_native(ink,actual,detail=0)
        agreement=float(np.mean(expected_codes==actual_codes));assert agreement>.999
        record('full_dpid_six_colour_pipeline_'+name,pixel_agreement=agreement)
    line_records=[]
    for width in [1,2,4,8]:
        rgb=np.full((960,960,3),255,dtype=np.uint8);rgb[:,321:321+width]=20
        for use_dpid in [False,True]:
            sampled=native(lib,rgb,(240,240),use_dpid=use_dpid)
            codes=ink_native(ink,sampled,detail=0 if use_dpid else .8)
            line_records.append({'source_line_width':width,'target_line_width':width/4,
                                 'sampling':'dpid' if use_dpid else 'lanczos',
                                 'black_pixels_in_4px_corridor_per_row':float(np.mean(np.sum(codes[:,79:83]==0,axis=1))),
                                 'rows_with_black_in_corridor':float(np.mean(np.any(codes[:,79:83]==0,axis=1)))})
    assert line_records[1]['black_pixels_in_4px_corridor_per_row']>line_records[0]['black_pixels_in_4px_corridor_per_row']
    record('subpixel_dark_line_survives_final_six_colour_conversion',
           lanczos_black_pixels_per_row=line_records[0]['black_pixels_in_4px_corridor_per_row'],
           dpid_black_pixels_per_row=line_records[1]['black_pixels_in_4px_corridor_per_row'],
           note='0.25px white-background line; increased ink coverage may thicken features')
    rgb=rng.integers(0,256,(3000,4000,3),dtype=np.uint8)
    start=time.perf_counter();native(lib,rgb,(240,240),padding=0);elapsed=time.perf_counter()-start
    record('12mp_desktop_sampling_timing',seconds=elapsed,note='Windows desktop; includes test buffer copies, not iPhone performance')
    target=ROOT/'results/dpid240';target.mkdir(exist_ok=True,parents=True)
    (target/'native_tests.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
    (target/'line_diagnostics.json').write_text(json.dumps(line_records,indent=2),encoding='utf-8')
    print(len(records),'checks passed',flush=True)


if __name__=='__main__':main()
