// Current-track evidence only. A player's supported MIME list describes what it
// *can* open, not what it is playing. Browser identity is deliberately irrelevant.
function kind(player, override) {
    if (!player) return "unknown";
    if (override === "video" || override === "music") return override;
    const m = player.metadata || {};
    const mime = String(m["xesam:contentType"] || m["mpris:contentType"] || "").toLowerCase();
    if (mime.indexOf("video/") === 0) return "video";
    if (mime.indexOf("audio/") === 0) return "music";
    const url = String(m["xesam:url"] || "").split(/[?#]/)[0].toLowerCase();
    if (/\.(mp4|mkv|webm|mov|avi|m4v|ogv|mpeg|mpg)$/.test(url)) return "video";
    if (/\.(mp3|flac|wav|m4a|aac|opus|oga|aiff|alac)$/.test(url)) return "music";
    return "unknown";
}
function time(seconds) {
    if (!isFinite(seconds) || seconds < 0) return "—:—";
    const s = Math.floor(seconds), h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60;
    return (h ? h + ":" + String(m).padStart(2, "0") : String(m)) + ":" + String(s % 60).padStart(2, "0");
}
