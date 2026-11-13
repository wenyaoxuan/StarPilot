import { AttitudeFilter, FILTER_OFF, FILTER_SLERP, FILTER_ONE_EURO } from './attitudefilter.mjs';
const D2R=Math.PI/180;
function qAxis(axis,deg){const h=deg*D2R/2;return{x:axis.x*Math.sin(h),y:axis.y*Math.sin(h),z:axis.z*Math.sin(h),w:Math.cos(h)}}
function qMul(a,b){return{x:a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,y:a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,z:a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w,w:a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z}}
function qAngle(a,b){const d=Math.min(1,Math.abs(a.x*b.x+a.y*b.y+a.z*b.z+a.w*b.w));return 2*Math.acos(d)/D2R}
function rms(arr){return Math.sqrt(arr.reduce((s,x)=>s+x*x,0)/arr.length)}
function simulate(mode, noiseDeg, stepDeg, seconds=6, rate=10){
 const f=new AttitudeFilter(mode); const errs=[]; let stepTime=-1; let settle=-1; let out;
 const base=qAxis({x:0,y:0,z:1},0);
 for(let i=0;i<seconds*rate;i++){
  const t=i/rate; const ts=Math.round(t*1e9)+1000000;
  let q=qAxis({x:1,y:0,z:0}, (Math.sin(i*1.7)*noiseDeg)+(Math.sin(i*3.1)*noiseDeg*0.4));
  if(t>=2) q=qMul(qAxis({x:0,y:1,z:0},stepDeg),q);
  out=f.update(q.x,q.y,q.z,q.w,ts,Date.now());
  if(out.valid){
   const e=qAngle(out, stepDeg && t>=2?qAxis({x:0,y:1,z:0},stepDeg):{x:0,y:0,z:0,w:1});
   errs.push(e);
   if(t>=2){if(stepTime<0&&e<=3)stepTime=t-2; if(stepTime<0)settle=-1;}
  }
 }
 return {mode, last:qAngle(out,qAxis({x:0,y:1,z:0},stepDeg)), rms:rms(errs), settle:stepTime};
}
for(const mode of [FILTER_OFF,FILTER_SLERP,FILTER_ONE_EURO]){
 console.log('mode',mode,simulate(mode,1.5,30));
}
// q/-q input
const f=new AttitudeFilter(FILTER_ONE_EURO);let q=qAxis({x:0,y:0,z:1},30);
for(let i=0;i<5;i++){const s=i%2?-1:1;let r=f.update(q.x*s,q.y*s,q.z*s,q.w*s,1000000+i*1e8,Date.now());if(i===4)console.log('q/-q out',r.x.toFixed(3),r.w.toFixed(3));}
// gap reset
const f2=new AttitudeFilter(FILTER_ONE_EURO); f2.update(0,0,0,1,1000000,Date.now()); const g=f2.update(0,0,0,1,2500000000,Date.now()); console.log('gap reset',g.reset,g.reason,g.dtMs);
