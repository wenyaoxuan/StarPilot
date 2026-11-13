import { AttitudeFilter, FILTER_OFF, FILTER_SLERP, FILTER_ONE_EURO } from './attitudefilter.mjs';
const D2R=Math.PI/180;
function qAxis(axis,deg){const h=deg*D2R/2;return{x:axis.x*Math.sin(h),y:axis.y*Math.sin(h),z:axis.z*Math.sin(h),w:Math.cos(h)}}
function qMul(a,b){return{x:a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,y:a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,z:a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w,w:a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z}}
function qAng(a,b){const d=Math.min(1,Math.abs(a.x*b.x+a.y*b.y+a.z*b.z+a.w*b.w));return 2*Math.acos(d)/D2R}
const id={x:0,y:0,z:0,w:1};
const step=qAxis({x:0,y:1,z:0},30);
for(const mode of [FILTER_OFF,FILTER_SLERP,FILTER_ONE_EURO]){
 const f=new AttitudeFilter(mode); let errs=[]; let inputErrs=[]; let out=null; let response=-1;
 for(let i=0;i<60;i++){
  const t=i/10; const noisy=qAxis({x:1,y:0,z:0}, Math.sin(i*1.7)*1.5+Math.sin(i*3.1)*0.6);
  const q=t>=2?qMul(step,noisy):noisy;
  out=f.update(q.x,q.y,q.z,q.w,1000000+i*1e8,Date.now());
  if(t<1.8){errs.push(qAng(out,id)); inputErrs.push(qAng(q,id));}
  if(t>=2 && response<0 && qAng(out,step)<=1) response=t-2;
 }
 console.log('mode',mode,'staticOutRMS',Math.sqrt(errs.reduce((s,x)=>s+x*x,0)/errs.length).toFixed(2),'staticInputRMS',Math.sqrt(inputErrs.reduce((s,x)=>s+x*x,0)/inputErrs.length).toFixed(2),'step<1deg',response.toFixed(1));
}
