"""Compile/test the actual App C code on Windows, with an independent Python oracle."""
import ctypes as ct
import json
import os
import subprocess
import time
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter
from scipy.optimize import minimize
from experiment import fixtures
from resample import photo_resize
import hink_model as hm

ROOT=Path(__file__).resolve().parent
CORE=ROOT.parents[1]/'ios/BrushSDK/Core/Support/ImageDither/XTInkPhotoCore.c'


def load_native():
    dll=ROOT/'.build/ink_photo.dll'
    dll.parent.mkdir(exist_ok=True)
    subprocess.run([str(Path(os.environ.get('XT_ZIG', ROOT/'.runtime/ziglang/zig.exe'))),'cc','-std=c11','-O2','-Wall','-Wextra','-Werror',
                    '-shared','-Wl,--export-all-symbols',str(CORE),'-o',str(dll)],check=True)
    lib=ct.CDLL(str(dll)); p=ct.POINTER(ct.c_uint8); d=ct.POINTER(ct.c_double);s=ct.c_size_t
    lib.XTInkPrepareRGBA.argtypes=[p,s,s,s,ct.c_double,d,d]
    lib.XTInkQuantizeRGBA.argtypes=[p,s,s,s,p,s,ct.c_int,ct.c_double,ct.c_double]
    lib.XTInkRenderIndices.argtypes=[p,s,s,s,p,s,ct.c_int,ct.c_int,ct.c_int]
    return lib


def native(lib,rgb,detail=.8,edge=.55,dither=True,padding=0,prepared=False):
    src=np.full((240,960+padding),93,dtype=np.uint8)
    src[:,:960].reshape(240,240,4)[...,:3]=rgb
    src[:,:960].reshape(240,240,4)[...,3]=255
    p=ct.POINTER(ct.c_uint8);d=ct.POINTER(ct.c_double)
    if prepared:
        xyz=np.empty((240,240,3));lab=np.empty_like(xyz)
        assert lib.XTInkPrepareRGBA(src.ctypes.data_as(p),240,240,src.strides[0],detail,
                                  xyz.ctypes.data_as(d),lab.ctypes.data_as(d))==1
        return xyz,lab
    codes=np.full((240,240+padding),99,dtype=np.uint8)
    assert lib.XTInkQuantizeRGBA(src.ctypes.data_as(p),240,240,src.strides[0],codes.ctypes.data_as(p),
                               codes.strides[0],dither,detail,edge)==1
    assert np.all(codes[:,240:]==99)
    return codes[:,:240].copy()


def render(lib,codes,physical=True,flip_h=False,flip_v=False):
    output=np.full((240,972),91,dtype=np.uint8)
    p=ct.POINTER(ct.c_uint8)
    assert lib.XTInkRenderIndices(codes.ctypes.data_as(p),240,240,codes.strides[0],output.ctypes.data_as(p),
                                  output.strides[0],physical,flip_h,flip_v)==1
    assert np.all(output[:,960:]==91)
    rgba=output[:,:960].reshape(240,240,4)
    assert np.all(rgba[...,3]==255)
    return rgba[...,:3]


def line_diagnostics():
    # Sample 4x sources, with phase, angle and 0.5/1/2 output-pixel widths.
    # Count visible black pixels near the known centre line on every interior row.
    rows=[]
    for width in [.5,1,2]:
        for slope in [0,.35]:
            yy,xx=np.indices((960,960)); centre=320+slope*yy+.37*4
            mask=np.abs(xx-centre)<=width*4/2
            rgb=np.full((960,960,3),255,dtype=np.uint8);rgb[mask]=45
            sample=np.asarray(photo_resize(Image.fromarray(rgb),(240,240),0))
            a,g=hm.prepare(sample,0);b,h=hm.prepare(sample,.8)
            # Pixel-centre geometry of a 4:1 resize, not integer grid corners.
            line=80+slope*np.arange(240)+.37-.375+slope*.375
            for edge in [0,.35,.55,.75]:
                codes=hm.diffuse(a if edge==0 else b,g if edge==0 else h,True,edge)
                present=[];contrast=[];offset=[]
                for y in range(10,230):
                    x=int(round(line[y])); stripe=codes[y,max(0,x-1):min(240,x+2)]==0
                    present.append(bool(stripe.any()))
                    # Black coverage in 3-pixel corridor minus side background.
                    bg=np.concatenate([codes[y,x-8:x-4],codes[y,x+5:x+9]])==0
                    contrast.append(float(stripe.mean()-bg.mean()))
                    if stripe.any():offset.append(abs((np.flatnonzero(stripe)+x-1).mean()-line[y]))
                rows.append({'width_px':width,'slope':slope,'edge':edge,
                             'rows_with_black_near_line':float(np.mean(present)),
                             'line_minus_background_coverage':float(np.mean(contrast)),
                             'mean_offset_px':float(np.mean(offset)) if offset else None})
    return rows


def main():
    lib=load_native(); records=[]
    def record(name,**values):
        records.append({'test':name,'passed':True,**values});print(name,'PASS',values,flush=True)
    rng=np.random.default_rng(20261023)
    source=rng.integers(0,256,(240,240,3),dtype=np.uint8)
    for strength in [0,.8,1]:
        a,g=hm.prepare(source,strength);b,h=native(lib,source,detail=strength,prepared=True,padding=12)
        error=float(max(np.max(abs(a-b)),np.max(abs(g-h))))
        assert error<1e-8,error
        record(f'python_native_preparation_{strength}',max_float_error=error)
    for name,image in list(fixtures())[:4]:
        rgb=np.asarray(photo_resize(image,(240,240),0))
        expected=hm.quantize(rgb)
        start=time.perf_counter();actual=native(lib,rgb,padding=12);elapsed=time.perf_counter()-start
        agreement=float(np.mean(expected==actual))
        # Error diffusion amplifies tiny floating differences; report actual agreement.
        assert agreement>.999,agreement
        record('python_native_'+name,pixel_agreement=agreement,desktop_seconds=elapsed)
    codes=np.tile(np.repeat(hm.CODES,40),(240,1))
    for physical in [False,True]:
        for fh,fv in [(False,False),(True,False),(False,True),(True,True)]:
            pattern=codes.copy();pattern[120:]=np.roll(pattern[120:],17,axis=1)
            expected=hm.preview(pattern,physical)
            if fh:expected=expected[:,::-1]
            if fv:expected=expected[::-1]
            assert np.array_equal(render(lib,pattern,physical,fh,fv),expected)
    record('six_codes_marker_preview_and_all_payload_flips')
    # Independent constrained optimisation checks the convex-hull projection.
    targets=rng.uniform(0,.7,(20,3))
    projected=hm.project_gamut(targets)
    for target,point in zip(targets,projected):
        result=minimize(lambda z:float(np.sum((z@hm.XYZ-target)**2*[1,2,1])),np.ones(6)/6,
                        method='SLSQP',bounds=[(0,1)]*6,constraints=[{'type':'eq','fun':lambda z:z.sum()-1}],
                        options={'ftol':1e-13,'maxiter':300})
        assert result.success
        assert np.linalg.norm(point-result.x@hm.XYZ)<2e-6
    record('gamut_projection_vs_independent_scipy_constrained_optimisation')
    for value,code in [(0,0),(255,1)]:
        rgb=np.full((240,240,3),value,dtype=np.uint8)
        assert np.all(native(lib,rgb)==code)
    record('source_black_white_are_panel_black_white')
    gray=np.tile(np.arange(240,dtype=np.uint8),(240,1));gray=np.repeat(gray[...,None],3,axis=-1)
    indices=native(lib,gray)
    assert set(np.unique(indices))<=set([0,1])
    record('neutral_ramp_has_no_coloured_speckles')
    for value in [30,90,170,240]:
        rgb=np.full((240,240,3),value,dtype=np.uint8)
        noise=rng.integers(-1,2,(240,240,1));rgb=np.clip(rgb.astype(int)+noise,0,255).astype(np.uint8)
        a,g=native(lib,rgb,detail=0,prepared=True);b,h=native(lib,rgb,prepared=True)
        assert np.max(abs(g-h))<1e-10
    record('low_amplitude_neutral_noise_not_sharpened')
    a,g=native(lib,source,detail=0,prepared=True);b,h=native(lib,source,prepared=True)
    assert np.max(abs(g[...,0]-h[...,0]))<=2+1e-9
    assert np.max(abs(g[...,1:]-h[...,1:]))==0
    record('detail_is_bounded_2_Lstar_preserving_a_b')
    direct=native(lib,source,dither=False)
    assert np.array_equal(direct,hm.quantize(source,dither=False))
    assert set(np.unique(direct))<=set(hm.CODES)
    record('colour_level_mode_is_single_quantisation_without_diffusion')
    p=ct.POINTER(ct.c_uint8);src=np.zeros((240,240,4),dtype=np.uint8);dest=np.zeros((240,240),dtype=np.uint8)
    assert lib.XTInkQuantizeRGBA(src.ctypes.data_as(p),200,240,960,dest.ctypes.data_as(p),240,1,.8,.55)==0
    assert lib.XTInkQuantizeRGBA(src.ctypes.data_as(p),240,240,959,dest.ctypes.data_as(p),240,1,.8,.55)==0
    assert lib.XTInkQuantizeRGBA(src.ctypes.data_as(p),240,240,960,dest.ctypes.data_as(p),240,1,float('nan'),.55)==0
    dest[0,0]=4
    assert lib.XTInkRenderIndices(dest.ctypes.data_as(p),240,240,240,src.ctypes.data_as(p),960,1,0,0)==0
    record('invalid_size_stride_nan_and_unknown_colour_are_rejected')
    rows=line_diagnostics()
    for row in rows:
        if row['edge']!=.55:continue
        baseline=next(r for r in rows if r['width_px']==row['width_px'] and r['slope']==row['slope'] and r['edge']==0)
        assert row['rows_with_black_near_line']>=baseline['rows_with_black_near_line']-.05
        assert row['mean_offset_px']<.5
    line=next(r for r in rows if r['width_px']==1 and r['slope']==.35 and r['edge']==.55)
    baseline=next(r for r in rows if r['width_px']==1 and r['slope']==.35 and r['edge']==0)
    assert line['line_minus_background_coverage']>=baseline['line_minus_background_coverage']
    assert line['mean_offset_px']<=baseline['mean_offset_px']
    record('final_six_colour_subpixel_line_coverage_and_location',
           diagonal_1px_coverage_before=baseline['line_minus_background_coverage'],
           diagonal_1px_coverage_after=line['line_minus_background_coverage'],
           note='White background synthetic diagnostic; not a universal photo quality score')
    result=ROOT/'results/hink240';result.mkdir(exist_ok=True,parents=True)
    (result/'native_tests.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
    (result/'line_diagnostics.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    print('Line diagnostics saved; these measure black coverage, not recovered information.',flush=True)


if __name__=='__main__':main()
