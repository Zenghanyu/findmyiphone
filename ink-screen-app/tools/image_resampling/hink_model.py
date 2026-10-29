"""Independent HINK 240x240 six-colour prototype, NOT the closed SDK.

Factory Lab is provisionally D65/2deg. XYZ mixtures model area reflectance;
this is a nominal preview, without a measured optical blur/MTF model.
"""
from itertools import combinations
import numpy as np
from scipy.ndimage import convolve, maximum_filter, minimum_filter
from numba import njit

WHITE = np.array([.95047, 1., 1.08883])
LAB = np.array([[10,10,-12], [66.5,-4,-2], [65,-12,67.5],
                [26,41,30], [30,6,-39], [35,-24,10]], dtype=float)
CODES = np.array([0,1,2,3,5,6], dtype=np.uint8)
MARKERS = np.array([[0,0,0], [255,255,255], [255,255,0],
                    [255,0,0], [0,0,255], [0,255,0]], dtype=np.uint8)
MATRIX = np.array([[.4124564,.3575761,.1804375],
                   [.2126729,.7151522,.0721750],
                   [.0193339,.1191920,.9503041]])


def xyz_to_lab(xyz):
    t = np.asarray(xyz) / WHITE
    f = np.where(t > (6/29)**3, np.cbrt(t), t/(3*(6/29)**2) + 4/29)
    return np.stack([116*f[...,1]-16, 500*(f[...,0]-f[...,1]),
                     200*(f[...,1]-f[...,2])], axis=-1)


def lab_to_xyz(lab):
    lab = np.asarray(lab)
    y = (lab[...,0]+16)/116
    f = np.stack([y+lab[...,1]/500, y, y-lab[...,2]/200], axis=-1)
    return WHITE * np.where(f > 6/29, f**3, 3*(6/29)**2*(f-4/29))


XYZ = lab_to_xyz(LAB)


def rgb_to_xyz(rgb):
    v = np.asarray(rgb, dtype=float)/255
    v = np.where(v <= .04045, v/12.92, ((v+.055)/1.055)**2.4)
    return v @ MATRIX.T


def preview(codes, physical=True):
    palette = MARKERS
    if physical:
        v = XYZ @ np.linalg.inv(MATRIX).T
        v = np.where(v <= .0031308, v*12.92, 1.055*np.maximum(v,0)**(1/2.4)-.055)
        palette = np.floor(np.clip(v,0,1)*255+.5).astype(np.uint8)
    lut = np.zeros((7,3), dtype=np.uint8)
    lut[CODES] = palette
    return lut[codes]


def smooth(a,b,v):
    t = np.clip((v-a)/(b-a),0,1)
    return t*t*(3-2*t)


def prepare(rgb, strength=.8):
    lab = xyz_to_lab(rgb_to_xyz(rgb))
    l = lab[...,0].copy()
    blur = convolve(l, np.outer([1,2,1],[1,2,1])/16, mode='nearest')
    lo, hi = minimum_filter(l,3,mode='nearest'), maximum_filter(l,3,mode='nearest')
    detail = l-blur
    # A ridge can gain <=1.5 L*. Ordinary step edges cannot gain new extrema.
    p = np.pad(l,1,mode='edge')
    ridge = np.zeros(l.shape)
    for dy,dx in [(0,1),(1,0),(1,1),(1,-1)]:
        a = p[1+dy:1+dy+l.shape[0],1+dx:1+dx+l.shape[1]]-l
        b = p[1-dy:1-dy+l.shape[0],1-dx:1-dx+l.shape[1]]-l
        ridge = np.maximum(ridge, np.where(a*b>0,np.minimum(abs(a),abs(b)),0))
    extra = np.minimum(1.5,.08*(hi-lo))*smooth(1,4,ridge)
    delta = strength*detail*smooth(.5,2,abs(detail))*smooth(4,16,hi-lo)
    cap = np.minimum(2,.12*(hi-lo))
    delta = np.clip(np.clip(delta,-cap,cap),lo-l-extra,hi-l+extra)
    lab[...,0] = np.clip(l+delta,0,100)
    # Affine media-relative mapping: sRGB black/white -> panel black/white.
    target = XYZ[0]+lab_to_xyz(lab)/WHITE*(XYZ[1]-XYZ[0])
    return project_gamut(target), lab


def simplex_tables(palette=XYZ):
    # Project onto all simplices of <=4 vertices in the weighted XYZ metric.
    # This yields the nearest feasible area mixture without channel clipping.
    metric = np.array([1.,2.,1.])
    result = []
    for n in range(1,5):
        for ids in combinations(range(6),n):
            a = palette[list(ids)]
            e = (a[1:]-a[0]).T
            if n>1 and np.linalg.matrix_rank(e)<n-1:
                continue
            pinv = np.linalg.solve(e.T @ np.diag(metric) @ e, e.T @ np.diag(metric)) if n>1 else np.zeros((0,3))
            result.append((a[0],e,pinv))
    return result


TABLES = simplex_tables()


def project_gamut(target):
    best = np.zeros_like(target)
    distance = np.full(target.shape[:-1],np.inf)
    for origin,e,pinv in TABLES:
        u = (target-origin) @ pinv.T
        valid = (u>=-1e-9).all(-1) & (u.sum(-1)<=1+1e-9)
        point = origin+u@e.T
        d = ((target-point)**2 * [1,2,1]).sum(-1)
        take = valid & (d<distance)
        best[take], distance[take] = point[take], d[take]
    return best


@njit(cache=True)
def lab_scalar(xyz):
    f = np.empty(3)
    for c in range(3):
        v=xyz[c]/WHITE[c]
        f[c] = v**(1/3) if v>(6/29)**3 else v/(3*(6/29)**2)+4/29
    return np.array([116*f[1]-16,500*(f[0]-f[1]),200*(f[1]-f[2])])


@njit(cache=True)
def diffuse(target,guide,dither=True,edge=.55, palette_xyz=XYZ,palette_lab=LAB):
    h,w,_ = target.shape
    errors = np.zeros((h,w,3))
    out = np.empty((h,w),dtype=np.uint8)
    for y in range(h):
        direction = 1 if y%2==0 else -1
        for step in range(w):
            x=step if direction==1 else w-1-step
            value=target[y,x]+errors[y,x]
            # Bound transient diffusion error, not the underlying target colour.
            for c in range(3):
                value[c]=min(max(value[c],0),1.2)
            lab=lab_scalar(value)
            chroma=(guide[y,x,1]**2+guide[y,x,2]**2)**.5
            best=0
            distance=1e30
            for k in range(6):
                if chroma<4 and k>1:
                    continue  # Avoid green/blue speckles in neutral photographs.
                dl=lab-palette_lab[k]
                v=1.6*dl[0]**2+dl[1]**2+dl[2]**2
                if v<distance:
                    best,distance=k,v
            out[y,x]=CODES[best]
            if not dither:
                continue
            error=value-palette_xyz[best]
            for c in range(3):
                error[c]=min(max(error[c],-.25),.25)
            dxs=(direction,-direction,0,direction)
            dys=(0,1,1,1)
            weights=(7/16,3/16,5/16,1/16)
            conductance=np.zeros(4)
            base_sum=0.
            weight_sum=0.
            for i in range(4):
                xx,yy=x+dxs[i],y+dys[i]
                if 0<=xx<w and yy<h:
                    a=guide[y,x]-guide[yy,xx]
                    # Conductance is symmetric, based on undithered source Lab.
                    difference=(a[0]**2+.25*(a[1]**2+a[2]**2))**.5
                    t=min(max((difference-8)/16,0),1)
                    gate=1-edge*t*t*(3-2*t)
                    conductance[i]=weights[i]*max(gate,.05)
                    base_sum+=weights[i]
                    weight_sum+=conductance[i]
            # Preserve total interior error while routing it along a contour.
            # At image borders retain the ordinary kernel's missing-neighbour loss.
            for i in range(4):
                if conductance[i]>0:
                    xx,yy=x+dxs[i],y+dys[i]
                    errors[yy,xx]+=error*conductance[i]*base_sum/weight_sum
    return out


def quantize(rgb, detail=.8, edge=.55, dither=True):
    target,guide=prepare(rgb,detail)
    return diffuse(target,guide,dither,edge)
