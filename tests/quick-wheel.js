const fs=require('fs'),vm=require('vm'),assert=require('assert');
const navigation={};vm.createContext(navigation);
vm.runInContext(fs.readFileSync(__dirname+'/../quickshell/core/WheelNavigation.js','utf8'),navigation);
const cx=320,cy=280,inner=78,outer=224;
for(let i=0;i<8;i++) {
 const angle=(-90+i*45)*Math.PI/180;
 assert.equal(navigation.indexAt(cx+150*Math.cos(angle),cy+150*Math.sin(angle),cx,cy,inner,outer,8),i);
}
assert.equal(navigation.indexAt(cx,cy,cx,cy,inner,outer,8),-1);
assert.equal(navigation.indexAt(cx,cy-225,cx,cy,inner,outer,8),-1);
assert.equal(navigation.indexAt(NaN,cy,cx,cy,inner,outer,8),-1);
assert.equal(navigation.indexAt(cx,cy-150,cx,cy,inner,outer,0),-1);
assert.equal(navigation.cycle(7,1,8),0);assert.equal(navigation.cycle(0,-1,8),7);
assert.equal(navigation.cycle(-1,1,8),0);assert.equal(navigation.cycle(-1,-1,8),7);
assert.equal(navigation.cycle(0,1,0),-1);
assert.equal(navigation.clamp(-20,244,800),244);assert.equal(navigation.clamp(2000,244,800),800);
assert.equal(navigation.clamp(200,300,100),200);
console.log('PASS: eight radial directions, centre/outside/invalid cancellation, keyboard wrap and edge clamping');
