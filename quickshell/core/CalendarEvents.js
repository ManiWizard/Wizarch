.pragma library
// Local events use ISO civil-date keys, independent of the display calendar.
function forDate(events,key) { return (events || []).filter(e=>e.date===key); }
function save(events,event) { return (events || []).filter(e=>e.id!==event.id).concat([event]); }
function remove(events,id) { return (events || []).filter(e=>e.id!==id); }
