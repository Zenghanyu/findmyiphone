"""DPID-style inverse-bilateral downsampling over exact area footprints.

Engineering variant, not a bitwise reproduction of a published implementation:
area reference -> light spatial smoothing -> contrast-weighted source integration.
"""
import numpy as np
from numba import njit
from resample import lanczos3

DEFAULT_EXPONENT = 1.5
DEFAULT_RATIO = 32.0
DEFAULT_BLEND = .9
NOISE_FLOOR = 2.0  # weighted RGB distance, encoded sRGB units 0..255


@njit(cache=True)
def _area(rgb,tw,th):
    sh,sw,_=rgb.shape
    result=np.zeros((th,tw,3))
    for y in range(th):
        top,bottom=y*sh/th,(y+1)*sh/th
        for x in range(tw):
            left,right=x*sw/tw,(x+1)*sw/tw
            total=0.
            for yy in range(int(np.floor(top)),min(sh,int(np.ceil(bottom)))):
                wy=max(0.,min(bottom,yy+1)-max(top,yy))
                for xx in range(int(np.floor(left)),min(sw,int(np.ceil(right)))):
                    weight=wy*max(0.,min(right,xx+1)-max(left,xx))
                    total+=weight
                    for c in range(3):result[y,x,c]+=weight*rgb[yy,xx,c]
            result[y,x]/=total
    return result


@njit(cache=True)
def _dpid(rgb,tw,th,exponent,ratio,blend):
    sh,sw,_=rgb.shape
    base=_area(rgb,tw,th)
    guide=np.zeros_like(base)
    kernel=(1.,6.,1.)
    for y in range(th):
        for x in range(tw):
            for j in range(-1,2):
                for i in range(-1,2):
                    yy=min(max(y+j,0),th-1);xx=min(max(x+i,0),tw-1)
                    guide[y,x]+=base[yy,xx]*kernel[j+1]*kernel[i+1]/64
    result=np.empty((th,tw,3),dtype=np.uint8)
    coeff=(.2126,.7152,.0722)
    for y in range(th):
        top,bottom=y*sh/th,(y+1)*sh/th
        for x in range(tw):
            left,right=x*sw/tw,(x+1)*sw/tw
            minimum=1e300;maximum=0.
            for yy in range(int(np.floor(top)),min(sh,int(np.ceil(bottom)))):
                for xx in range(int(np.floor(left)),min(sw,int(np.ceil(right)))):
                    d=0.
                    for c in range(3):d+=coeff[c]*(rgb[yy,xx,c]-guide[y,x,c])**2
                    raw=max(d,NOISE_FLOOR**2)**(exponent/2)
                    minimum=min(minimum,raw);maximum=max(maximum,raw)
            if maximum<=minimum*(1+1e-12) or ratio==1 or blend==0:
                for c in range(3):result[y,x,c]=np.uint8(np.floor(base[y,x,c]+.5+1e-9))
                continue
            weighted=np.zeros(3);total=0.
            for yy in range(int(np.floor(top)),min(sh,int(np.ceil(bottom)))):
                wy=max(0.,min(bottom,yy+1)-max(top,yy))
                for xx in range(int(np.floor(left)),min(sw,int(np.ceil(right)))):
                    coverage=wy*max(0.,min(right,xx+1)-max(left,xx))
                    d=0.
                    for c in range(3):d+=coeff[c]*(rgb[yy,xx,c]-guide[y,x,c])**2
                    weight=coverage*min(max(d,NOISE_FLOOR**2)**(exponent/2),minimum*ratio)
                    total+=weight
                    for c in range(3):weighted[c]+=rgb[yy,xx,c]*weight
            for c in range(3):
                value=base[y,x,c]+blend*(weighted[c]/total-base[y,x,c])
                result[y,x,c]=np.uint8(np.floor(min(max(value,0),255)+.5+1e-9))
    return result


def dpid(rgb,size,exponent=DEFAULT_EXPONENT,ratio=DEFAULT_RATIO,blend=DEFAULT_BLEND):
    rgb=np.asarray(rgb,dtype=np.uint8)
    if rgb.ndim!=3 or rgb.shape[2]!=3:raise ValueError('Expected RGB')
    tw,th=size
    if tw<1 or th<1 or not np.isfinite([exponent,ratio,blend]).all():raise ValueError('Invalid parameters')
    if not 0<=exponent<=4 or not 1<=ratio<=256 or not 0<=blend<=1:raise ValueError('Invalid parameters')
    sh,sw,_=rgb.shape
    if tw>sw or th>sh or (tw==sw and th==sh):
        return np.asarray(lanczos3(rgb,size),dtype=np.uint8)
    return _dpid(rgb,tw,th,exponent,ratio,blend)
