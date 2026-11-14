// Actual launcher model and QML mutation/command functions, with execution intercepted.
const fs = require('fs'), vm = require('vm'), assert = require('assert'), path = require('path');
const base = path.resolve(__dirname, '../quickshell/panels');
const Model = {}; vm.createContext(Model); vm.runInContext(fs.readFileSync(path.join(base,'LauncherModel.js'),'utf8'), Model);
const qml=fs.readFileSync(path.join(base,'LauncherView.qml'),'utf8');
function fn(name) { const start=qml.indexOf('function '+name+'('); assert(start>=0); const open=qml.indexOf('{',start); let depth=1,end=open+1; for(;depth;end++){if(qml[end]==='{')depth++;if(qml[end]==='}')depth--;} return qml.slice(start,end); }
let checks=0;
for(let columns=1;columns<=6;columns++) for(let mask=0;mask<256;mask++) {
 const entries=Array.from({length:16},(_,i)=>({kind:i%2 ? 'app':'group',group:{type: mask & (1<<(i/2)) ? 'large':'compact'}}));
 const {slots,height}=Model.layout(entries,columns,88,98,10), cells=new Set();
 slots.forEach(slot=>{assert(slot.x>=0 && slot.x+slot.width<=columns*98-10);assert(slot.y+slot.height<=height);assert.strictEqual(slot.width,slot.span*88+(slot.span-1)*10);for(let y=0;y<slot.span;y++)for(let x=0;x<slot.span;x++){const key=(slot.row+y)+':'+(slot.column+x);assert(!cells.has(key));cells.add(key);}});
 assert.strictEqual(JSON.stringify(Model.layout(entries,columns,88,98,10)),JSON.stringify({slots,height}));checks++;
}
const mixed=Model.layout([{kind:'app'},{kind:'group',group:{type:'large'}},{kind:'app'},{kind:'app'}],4,88,98,10).slots;
assert.strictEqual(Model.neighbor(mixed,0,'right'),1);assert.strictEqual(Model.neighbor(mixed,0,'down'),3);assert.strictEqual(Model.neighbor(mixed,1,'right'),2);
const source={key:'app:a',kind:'app'},target={key:'group:G',kind:'group'};
assert.strictEqual(Model.destination(source,target,50,50,100,100),'group');assert.strictEqual(Model.destination(source,target,8,50,100,100),'before');assert.strictEqual(Model.destination(source,target,92,50,100,100),'after');assert.strictEqual(Model.destination(source,source,50,50,100,100),'');
assert.strictEqual(Model.destination({key:'group:H',kind:'group'},target,50,50,100,100),'after');
assert.strictEqual(Model.iconSource('/tmp/a b#c.png',()=>{throw Error('named resolver used for path');}),'file:///tmp/a%20b%23c.png');assert.strictEqual(Model.iconSource('named',x=>'theme:'+x),'theme:named');assert.strictEqual(Model.iconSource('',()=>''),'');
let prefs={pinnedApps:['a','missing','b'], appGroups:[{name:'G',apps:['a']}],launcherOrder:['app:a','group:G','app:missing','app:b'],hiddenApps:[]};
let launches=[], dismissals=0;
const scope={Model,root:{preferences:prefs,setPreference:(k,v)=>prefs[k]=v,setPreferences:c=>Object.assign(prefs,c)},feedback:'',notice:'',recordRecent:()=>{},Quickshell:{execDetached:c=>launches.push(c)},panel:{dismiss:()=>dismissals++},commandMode:true,commandConfirmed:false,searchText:'> printf should-never-run',homeMode:false,selectedEntry:null,activateResultApp:()=>{},openGroup:()=>{},launchApp:()=>{}};
vm.createContext(scope);vm.runInContext(['reorderHome','moveAppToGroup','setGroupApp','setPinned','runSelected'].map(fn).join('\n'),scope);
const original=JSON.stringify(prefs);scope.reorderHome('app:a','app:a',true);scope.reorderHome('invalid','app:a',true);scope.reorderHome('app:a','invalid',true);assert.strictEqual(JSON.stringify(prefs),original);
scope.reorderHome('app:b','app:a',false);assert.strictEqual(prefs.launcherOrder.join(','),'app:b,app:a,group:G,app:missing');
scope.setGroupApp('G',{id:'b'},true);assert(prefs.pinnedApps.includes('b'));assert(prefs.appGroups[0].apps.includes('b'));
scope.moveAppToGroup({id:'b',name:'B'},prefs.appGroups[0]);assert(!prefs.pinnedApps.includes('b'));assert.strictEqual(prefs.appGroups[0].apps.filter(id=>id==='b').length,1);assert(prefs.pinnedApps.includes('missing'));assert(prefs.launcherOrder.includes('app:missing'));
scope.setGroupApp('G',{id:'a'},false);assert(prefs.pinnedApps.includes('a'));assert(!prefs.appGroups[0].apps.includes('a'));
scope.setPinned({id:'missing'},false);assert(!prefs.pinnedApps.includes('missing'));assert(!prefs.launcherOrder.includes('app:missing'));
scope.setPinned({id:'missing'},true);assert(prefs.pinnedApps.includes('missing'));assert(prefs.launcherOrder.includes('app:missing'));
scope.runSelected();assert.strictEqual(launches.length,0);assert(scope.commandConfirmed);scope.runSelected();assert.strictEqual(launches.length,1);assert.strictEqual(launches[0].join('|'),'sh|-c|printf should-never-run');assert.strictEqual(dismissals,1);
scope.searchText='>  ';scope.runSelected();assert.strictEqual(launches.length,1);
// Real app routing retains terminal argv and the working directory; no process launches.
const themeQml=fs.readFileSync(path.resolve(base,'../core/Theme.qml'),'utf8');
const launch=themeQml.match(/function launchApplication\(app\) \{([\s\S]*?)\n \}/)[0];
scope.Quickshell.env=()=>null;scope.Core={Theme:{}};vm.runInContext(launch,scope);scope.Core.Theme.launchApplication=scope.launchApplication;
vm.runInContext(fn('launchApp'),scope);scope.launchApp({id:'terminal',runInTerminal:true,command:['nvim','file with spaces'],workingDirectory:'/tmp/work dir'});
assert.strictEqual(launches[1].command.join('|'),'kitty|-e|nvim|file with spaces');assert.strictEqual(launches[1].workingDirectory,'/tmp/work dir');
scope.launchApp({id:'gui',command:['gui','argument with spaces'],workingDirectory:'/tmp/gui'});assert.strictEqual(launches[2].command.join('|'),'gui|argument with spaces');assert.strictEqual(launches[2].workingDirectory,'/tmp/gui');
assert.strictEqual(launches[2].environment.QT_QPA_PLATFORMTHEME,'gtk3');
scope.Quickshell.env=()=> 'qt6ct';scope.launchApp({id:'explicit',command:['gui']});assert.strictEqual(launches[3].environment.QT_QPA_PLATFORMTHEME,'qt6ct');
const launchCount=launches.length;scope.launchApp({id:'missing',name:'Missing',unavailable:true});assert.strictEqual(launches.length,launchCount);assert(scope.feedback.includes('unavailable'));
// Temporarily missing/hidden apps preserve saved identities and recover with the same ID.
scope.desktopExclusions={};scope.root.sortedApps=[];scope.DesktopEntries={byId:()=>null};
vm.runInContext(fn('savedApp'),scope);assert(scope.savedApp('missing').unavailable);
const restored={id:'missing',name:'Restored',command:['fixture'],noDisplay:false};scope.root.sortedApps=[restored];assert.strictEqual(scope.savedApp('missing'),restored);
scope.desktopExclusions={missing:'OnlyShowIn'};assert.strictEqual(scope.savedApp('missing'),null);assert(prefs.pinnedApps.includes('missing'));assert(Model.logicalOrder(prefs).includes('app:missing'));
console.log(`PASS: ${checks} mixed layouts, spatial navigation, drop classification, icon URLs, invalid/self reordering, pin/membership distinction, unavailable ID recovery, intercepted two-step command execution`);
