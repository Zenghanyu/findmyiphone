#include "XTInkPhotoCore.h"
#include <float.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

static const XTInkProfile profile = {
    "HINK-T0154A10-A2 (nominal D65/2deg)",240,240,27,27,{
        {0,{0,0,0},{10,10,-12}}, {1,{255,255,255},{66.5,-4,-2}},
        {2,{255,255,0},{65,-12,67.5}}, {3,{255,0,0},{26,41,30}},
        {5,{0,0,255},{30,6,-39}}, {6,{0,255,0},{35,-24,10}}
    }
};
static const double white[3] = {.95047,1,1.08883};
static const double matrix[3][3] = {
    {.4124564,.3575761,.1804375}, {.2126729,.7151522,.0721750},
    {.0193339,.1191920,.9503041}
};
static double clamp(double v,double a,double b) { return fmax(a,fmin(v,b)); }
static double smooth(double a,double b,double v) {
    double t=clamp((v-a)/(b-a),0,1); return t*t*(3-2*t);
}
static int at(int i,int n) { return i<0?0:(i>=n?n-1:i); }
static int valid(size_t w,size_t h,size_t stride) {
    return w==profile.width && h==profile.height && stride>=w*4 && stride<=SIZE_MAX/h;
}
static void labXYZ(const double lab[3],double xyz[3]) {
    double y=(lab[0]+16)/116, f[3]={y+lab[1]/500,y,y-lab[2]/200};
    for (int c=0;c<3;c++) xyz[c]=white[c]*(f[c]>6.0/29?f[c]*f[c]*f[c]:3*pow(6.0/29,2)*(f[c]-4.0/29));
}
static void xyzLab(const double xyz[3],double lab[3]) {
    double f[3];
    for(int c=0;c<3;c++) {
        double v=xyz[c]/white[c];
        f[c]=v>pow(6.0/29,3)?cbrt(v):v/(3*pow(6.0/29,2))+4.0/29;
    }
    lab[0]=116*f[1]-16; lab[1]=500*(f[0]-f[1]); lab[2]=200*(f[1]-f[2]);
}
const XTInkProfile *XTInkHinkT0154A10A2(void) { return &profile; }

/* Affine projections onto all 56 simplices of a six-vertex convex hull.
 * Weighted XYZ squared distance uses diag(1,2,1). Physical area mixtures must
 * be in this hull; neither nearest-Lab clipping nor averaging Lab ensures this.
 * Tables are per-call, so concurrent storage/preview operations share no state.
 */
typedef struct { int n; double origin[3],e[3][3],pinv[3][3]; } Simplex;
static int inverse(const double a[3][3],double b[3][3],int n) {
    double t[3][6]={{0}};
    for(int i=0;i<n;i++) for(int j=0;j<n;j++) {t[i][j]=a[i][j]; t[i][j+n]=i==j;}
    for(int i=0;i<n;i++) {
        int pivot=i;
        for(int j=i+1;j<n;j++) if(fabs(t[j][i])>fabs(t[pivot][i])) pivot=j;
        if(fabs(t[pivot][i])<1e-18) return 0;
        for(int j=0;j<2*n;j++) {double v=t[i][j];t[i][j]=t[pivot][j];t[pivot][j]=v;}
        double divisor=t[i][i];
        for(int j=0;j<2*n;j++) t[i][j]/=divisor;
        for(int k=0;k<n;k++) if(k!=i) {
            double v=t[k][i]; for(int j=0;j<2*n;j++) t[k][j]-=v*t[i][j];
        }
    }
    for(int i=0;i<n;i++) for(int j=0;j<n;j++) b[i][j]=t[i][j+n];
    return 1;
}
static int makeTables(double palette[6][3],Simplex tables[56]) {
    int count=0;
    for(unsigned mask=1;mask<64;mask++) {
        int ids[6],n=0;
        for(int k=0;k<6;k++) if(mask&(1u<<k)) ids[n++]=k;
        if(n>4) continue;
        Simplex s={0};s.n=n-1;
        memcpy(s.origin,palette[ids[0]],sizeof(s.origin));
        double gram[3][3]={{0}}, inv[3][3]={{0}};
        for(int c=0;c<3;c++) for(int j=0;j<s.n;j++) s.e[c][j]=palette[ids[j+1]][c]-s.origin[c];
        for(int i=0;i<s.n;i++) for(int j=0;j<s.n;j++) for(int c=0;c<3;c++)
            gram[i][j]+=s.e[c][i]*s.e[c][j]*(c==1?2:1);
        if(s.n && !inverse(gram,inv,s.n)) continue;
        for(int i=0;i<s.n;i++) for(int c=0;c<3;c++) for(int j=0;j<s.n;j++)
            s.pinv[i][c]+=inv[i][j]*s.e[c][j]*(c==1?2:1);
        tables[count++]=s;
    }
    return count;
}
static void project(const double target[3],const Simplex *tables,int count,double result[3]) {
    double best=DBL_MAX;
    for(int i=0;i<count;i++) {
        const Simplex *s=&tables[i];double u[3]={0},sum=0;int ok=1;
        for(int j=0;j<s->n;j++) {
            for(int c=0;c<3;c++) u[j]+=s->pinv[j][c]*(target[c]-s->origin[c]);
            if(u[j]<-1e-9) ok=0;
            sum+=u[j];
        }
        if(!ok || sum>1+1e-9) continue;
        double p[3],distance=0;
        for(int c=0;c<3;c++) {
            p[c]=s->origin[c]; for(int j=0;j<s->n;j++) p[c]+=s->e[c][j]*u[j];
            distance+=(p[c]-target[c])*(p[c]-target[c])*(c==1?2:1);
        }
        if(distance<best) {best=distance;memcpy(result,p,sizeof(p));}
    }
}

int XTInkPrepareRGBA(const uint8_t *rgba,size_t w,size_t h,size_t stride,double strength,double *xyz,double *lab) {
    if(!rgba || !xyz || !lab || xyz==lab || !valid(w,h,stride) || !isfinite(strength)) return 0;
    strength=clamp(strength,0,1);
    double *luma=malloc(w*h*sizeof(double));
    if(!luma) return 0;
    double linear[256],palette[6][3];Simplex tables[56];
    for(int i=0;i<256;i++) {double v=i/255.0;linear[i]=v<=.04045?v/12.92:pow((v+.055)/1.055,2.4);}
    for(int k=0;k<6;k++) labXYZ(profile.colors[k].lab,palette[k]);
    int count=makeTables(palette,tables);
    for(size_t y=0;y<h;y++) for(size_t x=0;x<w;x++) {
        const uint8_t *p=rgba+y*stride+x*4; double v[3]={0};
        for(int c=0;c<3;c++) for(int j=0;j<3;j++) v[c]+=matrix[c][j]*linear[p[j]];
        xyzLab(v,lab+(y*w+x)*3);luma[y*w+x]=lab[(y*w+x)*3];
    }
    const int kernel[3]={1,2,1},dx[4]={1,0,1,-1},dy[4]={0,1,1,1};
    for(size_t y=0;y<h;y++) for(size_t x=0;x<w;x++) {
        double center=luma[y*w+x],lo=DBL_MAX,hi=-DBL_MAX,blur=0,ridge=0;
        for(int j=-1;j<=1;j++) for(int i=-1;i<=1;i++) {
            double v=luma[(size_t)at((int)y+j,(int)h)*w+at((int)x+i,(int)w)];
            lo=fmin(lo,v);hi=fmax(hi,v);blur+=v*kernel[i+1]*kernel[j+1]/16.0;
        }
        for(int i=0;i<4;i++) {
            double a=luma[(size_t)at((int)y+dy[i],(int)h)*w+at((int)x+dx[i],(int)w)]-center;
            double b=luma[(size_t)at((int)y-dy[i],(int)h)*w+at((int)x-dx[i],(int)w)]-center;
            if(a*b>0) ridge=fmax(ridge,fmin(fabs(a),fabs(b)));
        }
        double extra=fmin(1.5,.08*(hi-lo))*smooth(1,4,ridge),detail=center-blur;
        double delta=strength*detail*smooth(.5,2,fabs(detail))*smooth(4,16,hi-lo);
        double cap=fmin(2,.12*(hi-lo));
        delta=clamp(clamp(delta,-cap,cap),lo-center-extra,hi-center+extra);
        double *guide=lab+(y*w+x)*3;guide[0]=clamp(center+delta,0,100);
        double target[3];labXYZ(guide,target);
        for(int c=0;c<3;c++) target[c]=palette[0][c]+target[c]/white[c]*(palette[1][c]-palette[0][c]);
        project(target,tables,count,xyz+(y*w+x)*3);
    }
    free(luma);return 1;
}

int XTInkQuantizeRGBA(const uint8_t *rgba,size_t w,size_t h,size_t stride,uint8_t *codes,size_t codeStride,
                      int dither,double detailStrength,double edgeProtection) {
    if(!rgba || !codes || !valid(w,h,stride) || codeStride<w || codeStride>SIZE_MAX/h ||
       !isfinite(detailStrength) || !isfinite(edgeProtection)) return 0;
    double *xyz=malloc(w*h*3*sizeof(double)), *guide=malloc(w*h*3*sizeof(double));
    /* Only two error rows needed: O(width), no full-frame error buffer. */
    double *errors=calloc(w*2*3,sizeof(double));
    if(!xyz || !guide || !errors) {free(xyz);free(guide);free(errors);return 0;}
    if(!XTInkPrepareRGBA(rgba,w,h,stride,detailStrength,xyz,guide)) {free(xyz);free(guide);free(errors);return 0;}
    double palette[6][3];for(int k=0;k<6;k++) labXYZ(profile.colors[k].lab,palette[k]);
    edgeProtection=clamp(edgeProtection,0,1);
    for(size_t y=0;y<h;y++) {
        int direction=y%2?-1:1;
        for(size_t step=0;step<w;step++) {
            size_t x=direction==1?step:w-1-step,index=(y*w+x)*3;
            double value[3],lab[3];
            for(int c=0;c<3;c++) value[c]=clamp(xyz[index+c]+errors[((y%2)*w+x)*3+c],0,1.2);
            xyzLab(value,lab);
            double chroma=hypot(guide[index+1],guide[index+2]),best=DBL_MAX;int chosen=0;
            for(int k=0;k<6;k++) {
                if(chroma<4 && k>1) continue;
                double distance=0;
                for(int c=0;c<3;c++) {double v=lab[c]-profile.colors[k].lab[c];distance+=v*v*(c==0?1.6:1);}
                if(distance<best) {chosen=k;best=distance;}
            }
            codes[y*codeStride+x]=profile.colors[chosen].code;
            if(!dither) continue;
            double error[3];for(int c=0;c<3;c++) error[c]=clamp(value[c]-palette[chosen][c],-.25,.25);
            const int dx[4]={direction,-direction,0,direction},dy[4]={0,1,1,1};
            const double weights[4]={7.0/16,3.0/16,5.0/16,1.0/16};
            double conductance[4]={0},baseSum=0,weightSum=0;
            for(int i=0;i<4;i++) {
                int xx=(int)x+dx[i],yy=(int)y+dy[i];
                if(xx<0 || xx>=(int)w || yy>=(int)h) continue;
                double difference=0;
                for(int c=0;c<3;c++) {double v=guide[index+c]-guide[((size_t)yy*w+xx)*3+c];difference+=v*v*(c==0?1:.25);}
                double gate=1-edgeProtection*smooth(8,24,sqrt(difference));
                conductance[i]=weights[i]*fmax(gate,.05);
                baseSum+=weights[i];weightSum+=conductance[i];
            }
            /* Conserve interior error; redirect it along contours. The sum is
             * <=1, so this cannot amplify total error into an unbounded streak.
             * At borders keep the ordinary kernel's missing-neighbour loss.
             */
            for(int i=0;i<4;i++) if(conductance[i]>0) {
                int xx=(int)x+dx[i],yy=(int)y+dy[i];
                for(int c=0;c<3;c++) errors[(((size_t)yy%2)*w+xx)*3+c]+=error[c]*conductance[i]*baseSum/weightSum;
            }
        }
        memset(errors+(y%2)*w*3,0,w*3*sizeof(double));
    }
    free(xyz);free(guide);free(errors);return 1;
}

int XTInkRenderIndices(const uint8_t *codes,size_t w,size_t h,size_t codeStride,uint8_t *rgba,size_t stride,
                       int physical,int flipH,int flipV) {
    if(!codes || !rgba || !valid(w,h,stride) || codeStride<w || codeStride>SIZE_MAX/h) return 0;
    uint8_t colors[7][3]={{0}};int known[7]={0};
    double inv[3][3]={{0}};if(!inverse(matrix,inv,3)) return 0;
    for(int k=0;k<6;k++) {
        unsigned code=profile.colors[k].code;known[code]=1;
        double xyz[3];labXYZ(profile.colors[k].lab,xyz);
        for(int c=0;c<3;c++) {
            double v=0;for(int j=0;j<3;j++) v+=inv[c][j]*xyz[j];
            v=v<=.0031308?v*12.92:1.055*pow(v,1/2.4)-.055;
            colors[code][c]=physical?(uint8_t)floor(clamp(v,0,1)*255+.5):profile.colors[k].marker[c];
        }
    }
    for(size_t y=0;y<h;y++) for(size_t x=0;x<w;x++) {
        unsigned code=codes[(flipV?h-1-y:y)*codeStride+(flipH?w-1-x:x)];
        if(code>6 || !known[code]) return 0;
        uint8_t *p=rgba+y*stride+x*4;memcpy(p,colors[code],3);p[3]=255;
    }
    return 1;
}
