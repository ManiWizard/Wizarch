// -1 cancels pending reveal; 1 approaches the pill; 0 is pointer jitter.
function movement(x, y, previousX, previousY, center) {
    var dx = x - previousX, dy = y - previousY;
    var distanceChange = Math.abs(x - center) - Math.abs(previousX - center);
    if (dy > 0.5 || distanceChange > 0.5) return -1;
    if (dy < -0.5 || (distanceChange < -0.5 && Math.abs(dx) > 0.5)) return 1;
    return 0;
}
