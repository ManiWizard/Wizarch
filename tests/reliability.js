// Run with Node; exercises the actual queue, pointer policy and panel functions.
const fs = require('fs'), vm = require('vm'), assert = require('assert'), path = require('path');
const root = path.resolve(__dirname, '../quickshell');
function library(file) { const scope = {}; vm.createContext(scope); vm.runInContext(fs.readFileSync(path.join(root,file),'utf8'),scope); return scope; }
const q = library('core/PreferenceQueue.js');
let state=q.create();q.enqueue(state,{systemVolume:30});assert.strictEqual(q.take(state),null);
let loaded=q.load(state,{systemVolume:55,customField:'keep'});assert.strictEqual(loaded.systemVolume,30);assert.strictEqual(loaded.customField,'keep');
q.enqueue(state,{systemVolume:31,dnd:true});let batch=q.take(state);assert.strictEqual(batch.systemVolume,31);assert.strictEqual(q.take(state),null);
q.enqueue(state,{systemVolume:45});assert(q.validResponse(JSON.stringify(batch),batch));assert(!q.validResponse('oops',batch));assert(!q.validResponse('{}',batch));
q.finish(state,true);batch=q.take(state);assert.strictEqual(batch.systemVolume,45);
q.enqueue(state,{systemVolume:60,windowSpacing:35});q.finish(state,false);assert.strictEqual(state.pending.systemVolume,60);assert(state.error);assert.strictEqual(q.take(state),null);
q.retry(state);batch=q.take(state);assert.strictEqual(batch.systemVolume,60);assert.strictEqual(batch.windowSpacing,35);q.finish(state,true);assert.strictEqual(state.error,'');
const intent=library('core/RevealIntent.js');
assert.strictEqual(intent.movement(129,2,129,8,129),1); // upward
assert.strictEqual(intent.movement(129,8,129,2,129),-1); // downward
assert.strictEqual(intent.movement(100,0,90,0,129),1); // toward center
assert.strictEqual(intent.movement(90,0,100,0,129),-1); // away
assert.strictEqual(intent.movement(100.1,0,100,0,129),0); // jitter
assert.strictEqual(intent.movement(140,0,129,0,129),-1); // past center
function functionBody(file,name) {
 const text=fs.readFileSync(path.join(root,file),'utf8');const start=text.indexOf('function '+name+'(');assert(start>=0);
 const open=text.indexOf('{',start);let depth=1,i=open+1;for(;depth;i++){if(text[i]==='{')depth++;if(text[i]==='}')depth--;}
 return text.slice(start,i);
}
const Solar={};vm.createContext(Solar);vm.runInContext(fs.readFileSync(path.join(root,'core/Solar.js'),'utf8').replace(/^\.pragma.*$/mg,''),Solar);
const Dates={Solar};vm.createContext(Dates);vm.runInContext(fs.readFileSync(path.join(root,'core/CalendarDate.js'),'utf8').replace(/^\.pragma.*$/mg,'').replace(/^\.import.*$/mg,''),Dates);
const cal={page:new Date(2026,9,7,12),monthView:false,weekStart:1};
vm.runInNewContext(functionBody('panels/CalendarView.qml','dateAt')+'; cal.dateAt=dateAt;', {cal,Date,Dates,primary:"gregorian",page:cal.page,monthView:false});
for(let anchor=4;anchor<=10;anchor++){
 const context={Date,Dates,primary:"gregorian",page:new Date(2026,9,anchor,12),monthView:false,weekStart:1};vm.createContext(context);vm.runInContext(functionBody('panels/CalendarView.qml','dateAt'),context);
 for(let i=0;i<7;i++){const d=context.dateAt(i);assert.strictEqual(d.getDay(),new Date(2026,9,anchor-3+i,12).getDay());}
}
for(const [y,m,d] of [[2024,1,29],[2026,11,31],[2027,0,1]]) {
 const context={Date,Dates,primary:"gregorian",page:new Date(y,m,d,12),monthView:false,weekStart:1};vm.createContext(context);vm.runInContext(functionBody('panels/CalendarView.qml','dateAt'),context);assert.strictEqual(context.dateAt(3).getDate(),d);assert.strictEqual(context.dateAt(6).getTime(),new Date(y,m,d+3,12).getTime());
}
for(const [y,m,rows] of [[2021,1,4],[2026,9,5],[2026,2,6]]){
 const c={Date,Dates,primary:"gregorian",page:new Date(y,m,1,12),monthView:true,weekStart:1};vm.createContext(c);vm.runInContext(functionBody('panels/CalendarView.qml','dateAt'),c);assert.strictEqual(c.dateAt(0).getDay(),1);
 const offset=(c.page.getDay()+6)%7;assert.strictEqual(Math.ceil((offset+new Date(y,m+1,0).getDate())/7),rows);
}
console.log('PASS: queue ordering/load/failure/retry, pointer direction, calendar boundaries');
// Launcher model/mutations now have their own focused suite.
require('./launcher.js');
