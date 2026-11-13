import { enuVector, projectPoint, angularSepVec, screenDirection } from './skyprojection.mjs';
const W=466,H=466,FOV=60;
const cross=(a,b)=>({x:a.y*b.z-a.z*b.y,y:a.z*b.x-a.x*b.z,z:a.x*b.y-a.y*b.x});
const norm=a=>{const l=Math.hypot(a.x,a.y,a.z);return{x:a.x/l,y:a.y/l,z:a.z/l}};
function pose(az,alt,roll=0){
 const f=enuVector(az,alt); let r=norm(cross(f,{x:0,y:0,z:1})); let u=norm(cross(r,f));
 const c=Math.cos(roll*Math.PI/180),s=Math.sin(roll*Math.PI/180);
 const rr={x:r.x*c+u.x*s,y:r.y*c+u.y*s,z:r.z*c+u.z*s};
 const uu={x:-r.x*s+u.x*c,y:-r.y*s+u.y*c,z:-r.z*s+u.z*c};
 return {forward:f,right:rr,up:uu};
}
function show(name,poseObj,target){const q=projectPoint(poseObj,FOV,W,H,target);console.log(name,'screen',q.x.toFixed(1),q.y.toFixed(1),'z',q.z.toFixed(3),'vis',q.visible,'circle',q.insideCircle);return q;}
const pN=pose(0,0);
console.log('center N horizon 0/0');show('center',pN,enuVector(0,0));
show('east',pN,enuVector(90,0));show('south',pN,enuVector(180,0));show('west',pN,enuVector(270,0));show('zenith',pN,enuVector(0,90));
console.log('quarter FOV');show('az+15/alt0',pN,enuVector(15,0));show('az-15/alt0',pN,enuVector(-15+360,0));
console.log('roll 90');const pR=pose(0,0,90);show('target alt30 roll90',pR,enuVector(0,30));
console.log('behind z');const pb=pose(0,0);const q=projectPoint(pb,FOV,W,H,enuVector(180,0));console.log(q);
console.log('edge dir behind',screenDirection(q,W,H));
console.log('angle center-target',angularSepVec(enuVector(0,0),enuVector(0,30)).toFixed(3));
