.pragma library
.import "Solar.js" as Solar
// Civil dates are local noon; UTC ordinals avoid DST arithmetic.
var gregorianMonths = ["January","February","March","April","May","June","July","August","September","October","November","December"];
var solarMonths = ["Farvardin","Ordibehesht","Khordad","Tir","Mordad","Shahrivar","Mehr","Aban","Azar","Dey","Bahman","Esfand"];
var starts = null;
var minimum = new Date(1901,0,1,12), maximum = new Date(2099,11,31,12);
function noon(d) { return new Date(d.getFullYear(),d.getMonth(),d.getDate(),12); }
function ordinal(d) { return Math.round(Date.UTC(d.getFullYear(),d.getMonth(),d.getDate())/86400000); }
function addDays(d,n) { return new Date(d.getFullYear(),d.getMonth(),d.getDate()+n,12); }
function key(d) { return d.getFullYear()+"-"+String(d.getMonth()+1).padStart(2,"0")+"-"+String(d.getDate()).padStart(2,"0"); }
function supported(d) { return !isNaN(d.getTime()) && ordinal(d)>=ordinal(minimum) && ordinal(d)<=ordinal(maximum); }
function clamp(d) { return d<minimum ? noon(minimum) : d>maximum ? noon(maximum) : noon(d); }
function build() {
    if (starts) return;
    starts = [];
    var base = ordinal(new Date(1900,0,1,12)), y=1278, m=9;
    starts.push({ordinal:base-(Solar.days.charCodeAt(0)-65),year:y,month:m});
    for (var i=1;i<Solar.days.length;i++) {
        if (Solar.days.charCodeAt(i)===65) { m++; if(m===12){m=0;y++;} starts.push({ordinal:base+i,year:y,month:m}); }
    }
}
function parts(d,system) {
    if(system!=="solar") return {year:d.getFullYear(),month:d.getMonth(),day:d.getDate()};
    build(); var o=ordinal(d), lo=0, hi=starts.length-1;
    while(lo<hi){ var mid=Math.ceil((lo+hi)/2); if(starts[mid].ordinal<=o)lo=mid;else hi=mid-1; }
    var s=starts[lo]; return {year:s.year,month:s.month,day:o-s.ordinal+1};
}
function fromParts(y,m,day,system) {
    y+=Math.floor(m/12);m=((m%12)+12)%12;
    if(system!=="solar") return new Date(y,m,day,12);
    build(); var s=starts.find(s=>s.year===y && s.month===m);
    if(!s) return new Date(NaN);
    var utc=new Date((s.ordinal+day-1)*86400000); return new Date(utc.getUTCFullYear(),utc.getUTCMonth(),utc.getUTCDate(),12);
}
function first(d,s) { var a=parts(d,s);return fromParts(a.year,a.month,1,s); }
function monthDays(d,s) {
    var a=parts(d,s), begin=fromParts(a.year,a.month,1,s), next=fromParts(a.year,a.month+1,1,s);
    return ordinal(next)-ordinal(begin);
}
function firstWeekday(s,style) { return style==="saturday" ? 6 : style==="sunday" ? 0 : style==="monday" ? 1 : s==="solar" ? 6 : 1; }
function lastWeekday(s,style) { return (firstWeekday(s,style)+6)%7; }
function isDayOff(d,s,style) { return d.getDay()===lastWeekday(s,style); }
function weekdayName(index,s,style) { return ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][(firstWeekday(s,style)+index)%7]; }
function offset(d,s,style) { return (first(d,s).getDay()-firstWeekday(s,style)+7)%7; }
function weeks(d,s,style) { return Math.ceil((offset(d,s,style)+monthDays(d,s))/7); }
function dateAt(d,s,month,index,style) { return addDays(month ? first(d,s) : d,month ? index-offset(d,s,style) : index-3); }
function move(d,s,mode,n) {
    var a=parts(d,s), target=mode===0 ? addDays(d,7*n) : fromParts(a.year+(mode===2?n:0),a.month+(mode===1?n:0),1,s);
    return isNaN(target.getTime()) ? noon(n<0?minimum:maximum) : clamp(target);
}
function canMove(d,s,mode,n) {
    var target=move(d,s,mode,n), a=parts(d,s), b=parts(target,s);
    return mode===2 ? a.year!==b.year : mode===1 ? a.year!==b.year || a.month!==b.month : key(d)!==key(target);
}
function name(d,s) { return (s==="solar"?solarMonths:gregorianMonths)[parts(d,s).month]; }
function heading(d,s) { return name(d,s)+" "+parts(d,s).year; }
function fade(index) { return [0.18,0.40,0.70,1,0.70,0.40,0.18][Math.max(0,Math.min(6,index))]; }
