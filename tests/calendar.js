const fs=require('fs'), vm=require('vm'), assert=require('assert');
const root=__dirname+'/../quickshell/core/';
function script(name,context={}) { vm.createContext(context);vm.runInContext(fs.readFileSync(root+name,'utf8').replace(/^\.pragma.*$/mg,'').replace(/^\.import.*$/mg,''),context);return context; }
const Solar=script('Solar.js'), Dates=script('CalendarDate.js',{Solar}), Events=script('CalendarEvents.js');
const fmt=new Intl.DateTimeFormat('en-US-u-ca-persian',{year:'numeric',month:'numeric',day:'numeric'});
let count=0, leap=0;
for(let d=Dates.minimum; d<=Dates.maximum; d=Dates.addDays(d,1)) {
 const p=Dates.parts(d,'solar'); const oracle=Object.fromEntries(fmt.formatToParts(d).map(p=>[p.type,p.value]));
 assert.equal(p.year,+oracle.year);assert.equal(p.month+1,+oracle.month);assert.equal(p.day,+oracle.day);
 assert.equal(Dates.key(Dates.fromParts(p.year,p.month,p.day,'solar')),Dates.key(d));
 if(p.month===11 && p.day===30)leap++;
 count++;
}
assert(leap>40);
for(const s of ['solar','gregorian']) {
 for(let year=1902;year<2099;year++) {
  const date=new Date(year,6,15,12), p=Dates.parts(date,s);
  for(let m=0;m<12;m++) {
   const d=Dates.fromParts(p.year,m,1,s), weeks=Dates.weeks(d,s), days=Dates.monthDays(d,s);
   assert(weeks>=4 && weeks<=6); assert(days>=28 && days<=31);
   assert.equal(Dates.dateAt(d,s,true,0).getDay(),s==='solar'?6:1);
   const last=Dates.addDays(d,days-1);assert.equal(Dates.parts(last,s).month,m);
   assert.equal(Dates.parts(Dates.addDays(last,1),s).month,(m+1)%12);
  }
 }
}
for (const system of ['gregorian','solar']) {
 for (const [style,start] of [['saturday',6],['monday',1],['sunday',0]]) {
  for (let m=0;m<12;m++) {
   const date=Dates.fromParts(system==='solar'?1405:2026,m,1,system);
   const weeks=Dates.weeks(date,system,style), offset=Dates.offset(date,system,style);
   assert.equal(Dates.dateAt(date,system,true,0,style).getDay(),start);
   assert.equal(Dates.key(Dates.dateAt(date,system,true,offset,style)),Dates.key(date));
   assert.equal(Dates.weekdayName(0,system,style),['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][start]);
   assert.equal(Dates.lastWeekday(system,style),(start+6)%7);
   for(let i=0;i<7;i++) assert.equal(Dates.isDayOff(Dates.dateAt(date,system,true,i,style),system,style),i===6);
   assert(weeks*7>=offset+Dates.monthDays(date,system));
   assert.equal(Dates.key(Dates.dateAt(date,system,false,3,style)),Dates.key(date));
  }
 }
}
const today=new Date(2026,9,9,12);
assert.equal(Dates.key(Dates.dateAt(today,'solar',false,3)),Dates.key(today));
for(let i=0;i<7;i++)assert.equal(Dates.fade(i),Dates.fade(6-i));
assert.equal(Dates.key(Dates.move(Dates.minimum,'gregorian',0,-1)),Dates.key(Dates.minimum));
assert.equal(Dates.key(Dates.move(Dates.maximum,'solar',2,1)),Dates.key(Dates.maximum));
assert(!Dates.canMove(new Date(2099,11,1,12),'gregorian',1,1));
assert(!Dates.canMove(new Date(2099,6,1,12),'gregorian',2,1));
assert(!Dates.canMove(Dates.maximum,'solar',2,1));
assert(!Dates.canMove(Dates.minimum,'solar',1,-1));
let events=[{id:'one',date:'2026-10-09',title:'A',color:'',icon:''}];
assert.equal(Events.forDate(events,'2026-10-09').length,1);
assert.equal(Events.forDate(events,'2026-10-10').length,0);
assert.equal(Events.save(events,{id:'one',date:'2026-10-10'}).length,1);
assert.equal(Events.remove(events,'one').length,0);
console.log(`PASS: ${count} Solar Hijri oracle comparisons and round trips; month/year/leap boundaries, rolling week symmetry, range limits, event associations`);
