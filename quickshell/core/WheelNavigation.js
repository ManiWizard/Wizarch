// Clockwise sectors, starting at twelve o'clock; centre and outside cancel.
function indexAt(x, y, cx, cy, innerRadius, outerRadius, count) {
    if (count <= 0 || ![x,y,cx,cy,innerRadius,outerRadius].every(Number.isFinite)) return -1;
    const dx=x-cx, dy=y-cy, distance=Math.hypot(dx,dy);
    if (distance < innerRadius || distance > outerRadius) return -1;
    const tau=2*Math.PI, step=tau/count;
    const angle=(Math.atan2(dx,-dy)+tau+step/2)%tau;
    return Math.floor(angle/step)%count;
}
function cycle(index, delta, count) {
    if (count <= 0) return -1;
    if (index < 0) return delta < 0 ? count-1 : 0;
    return ((index+delta)%count+count)%count;
}
function clamp(value, minimum, maximum) {
    return maximum < minimum ? (minimum+maximum)/2 : Math.min(maximum,Math.max(minimum,value));
}
