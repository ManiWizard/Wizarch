// Launcher-owned, pixel-free data and placement rules. Preferences retain desktop IDs.
function unique(values) { return values.filter((value, index) => values.indexOf(value) === index); }
function logicalOrder(preferences) {
    return unique((preferences.launcherOrder || []).concat(preferences.appGroups.map(g => "group:" + g.name), preferences.pinnedApps.map(id => "app:" + id)));
}
function reorder(order, source, target, after) {
    if (source === target || order.indexOf(source) < 0 || order.indexOf(target) < 0) return order;
    const next = order.filter(key => key !== source);
    next.splice(next.indexOf(target) + (after ? 1 : 0), 0, source);
    return next;
}
function layout(entries, columns, cellWidth, cellHeight, gap) {
    const occupied = {}, slots = [];
    let cursor = 0, rows = 0;
    entries.forEach(entry => {
        const span = entry.kind === "group" && (entry.group.type === "large" || entry.group.type === "stack") ? Math.min(2, columns) : 1;
        let row, column;
        while (true) {
            row = Math.floor(cursor / columns); column = cursor % columns;
            let fits = column + span <= columns;
            for (let y = 0; y < span; y++) for (let x = 0; x < span; x++) if (occupied[(row+y)+":"+(column+x)]) fits = false;
            if (fits) break;
            cursor++;
        }
        for (let y = 0; y < span; y++) for (let x = 0; x < span; x++) occupied[(row+y)+":"+(column+x)] = true;
        slots.push({x:column*(cellWidth+gap), y:row*(cellHeight+gap), width:span*cellWidth+(span-1)*gap, height:span*cellHeight+(span-1)*gap, row:row, column:column, span:span});
        rows = Math.max(rows, row+span); cursor++;
    });
    return {slots:slots, height:rows ? rows*cellHeight+(rows-1)*gap : 0};
}
function neighbor(slots, index, direction) {
    if (!slots.length) return 0;
    const source = slots[Math.min(index, slots.length-1)];
    let best = index, score = Infinity;
    slots.forEach((slot, i) => {
        if (i === index) return;
        const dx = slot.x+slot.width/2-source.x-source.width/2, dy = slot.y+slot.height/2-source.y-source.height/2;
        const primary = direction === "left" ? -dx : direction === "right" ? dx : direction === "up" ? -dy : dy;
        const horizontal = direction === "left" || direction === "right";
        const secondary = horizontal ? Math.max(0, source.y-slot.y-slot.height, slot.y-source.y-source.height) : Math.max(0, source.x-slot.x-slot.width, slot.x-source.x-source.width);
        const ahead = direction === "left" ? slot.x+slot.width <= source.x : direction === "right" ? slot.x >= source.x+source.width : direction === "up" ? slot.y+slot.height <= source.y : slot.y >= source.y+source.height;
        if (ahead && primary > 0 && primary+secondary*3 < score) { best=i; score=primary+secondary*3; }
    });
    return best;
}
function destination(source, target, x, y, width, height) {
    if (!source || !target || source.key === target.key) return "";
    if (target.kind === "group" && source.kind === "app" && x >= width*.25 && x <= width*.75 && y >= height*.2 && y <= height*.8) return "group";
    return x < width/2 ? "before" : "after";
}
function commandRoute(text, confirmed) {
    if (!text.startsWith(">") || !text.slice(1).trim()) return {action:"none"};
    return {action:confirmed ? "execute" : "confirm", command:text.slice(1).trim()};
}
function iconSource(icon, resolve) {
    if (!icon) return "";
    if (icon.startsWith("/")) return "file://"+icon.split("/").map(encodeURIComponent).join("/");
    if (icon.startsWith("file:")) return icon;
    return resolve(icon);
}
