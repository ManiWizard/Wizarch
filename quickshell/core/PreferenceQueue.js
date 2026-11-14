// Pure queue state: one batch in flight; later edits always win.
function create() { return {loaded: false, pending: {}, inFlight: null, error: ""}; }
function enqueue(state, changes) { state.pending = Object.assign({}, state.pending, changes); }
function load(state, saved) { state.loaded = true; return Object.assign({}, saved, state.pending); }
function take(state) {
    if (!state.loaded || state.inFlight || state.error || Object.keys(state.pending).length === 0) return null;
    state.inFlight = state.pending; state.pending = {}; return state.inFlight;
}
function finish(state, success) {
    if (!state.inFlight) return;
    if (!success) {
        state.pending = Object.assign({}, state.inFlight, state.pending);
        state.error = "Settings could not be saved";
    }
    state.inFlight = null;
    if (success && Object.keys(state.pending).length === 0) state.error = "";
}
function retry(state) { state.error = ""; }
function validResponse(text, batch) {
    try {
        var saved = JSON.parse(text);
        if (!saved || typeof saved !== "object" || Array.isArray(saved)) return false;
        return Object.keys(batch).every(function(key) { return JSON.stringify(saved[key]) === JSON.stringify(batch[key]); });
    } catch (e) { return false; }
}
