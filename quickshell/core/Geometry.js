.pragma library

// Calibrated logical-pixel measurements from the existing shell at a 13 px font.
// These are preferred dimensions, not feedback from a rendered control.
var calibration = {
    buttonHeight: 38, buttonPadding: 13, buttonVerticalPadding: 9,
    choiceInset: 12, choiceIndicatorInset: 25, choiceArrowInset: 22,
    switchWidth: 50, switchHitHeight: 32, switchTrackHeight: 28, switchInset: 3,
    // The existing checked thumb intentionally sits one pixel from the right edge.
    switchCheckedInset: 1,
    sliderHandle: 20, settingsTrack: 6, quickTrack: 8, sliderHeight: 32,
    glassSliderHeight: 30, glassHeight: 58, sliderHeader: 22, valueWidth: 90,
    glassIcon: 17, glassIconY: 1, glassLabelX: 26, glassSliderY: 24,
    rowHeight: 58, rowPadding: 9, rowControlWidth: 160, rowGap: 22,
    rowLabelInset: 2, rowLabelMinimum: 70, labelGap: 5,
    sectionPadding: 18, sectionGap: 12, contentGap: 8,
    quickSliderHeight: 44, quickSliderGap: 8, icon: 20, iconGap: 12,
    tileIcon: 21, tileWideInset: 12, tileWideIconY: 17, tileIconY: 11,
    tileLabelY: 38, tileWideLabelY: 12, tileDetailY: 30, tileTextInset: 3,
    tileWideTextX: 44, tileWideTextEnd: 8, tileDetailEnd: 52,
    actionIcon: 22, actionContent: 40, actionMinInset: 5,
    actionLabelBottom: 23, actionLabelHeight: 20, actionTextInset: 2,
    fontBody: 13, fontArrow: 17, fontTile: 11, fontDetail: 9,
    fontAction: 10, fontGlass: 11, fontLabel: 15, fontDescription: 12,
    fontSectionTitle: 17, fontValue: 11, fontHeaderClock: 16,
    fontHeaderWorkspace: 14, fontHeaderDate: 9, fontWorkspace: 10,
    pillWidth: 194, pillHeight: 42, panelWidth: 360, launcherWidth: 420,
    panelInset: 18, calendarInset: 22, panelTop: 4,
    revealHeight: 3, shoulderWidth: 32, shoulderHeight: 28,
    shoulderControlY: 8, shoulderControlX: 24, headerInset: 4,
    headerButtonWidth: 35, headerDividerWidth: 9, headerHighlightInset: 3,
    headerIcon: 18, headerTimeY: 2, headerDateY: 22, headerDateHeight: 12,
    headerDateGap: 4, headerDot: 2, emblemSize: 30, shadowOffset: 2,
    workspaceWidth: 18, workspaceHeight: 28, workspaceGap: 2, workspaceY: 7,
    calendarMinimumHeight: 180, screenContentReserve: 100,
    quickHeader: 30, quickHeaderGap: 7, quickHeaderIcon: 17,
    powerOutset: 6, powerGap: 4, quickTileHeight: 62,
    quickGridHeight: 78, quickGridInset: 8, quickGridGap: 4,
    quickActionSize: 38, quickActionLabelY: 41, quickActionLabelHeight: 25,
    quickActionStateY: 66, quickActionStateHeight: 12,
    traySize: 35, trayIcon: 22,
    wheelMaximumRadius: 200, wheelMinimumRadius: 100, wheelHorizontalReserve: 48,
    wheelVerticalReserve: 48
};

// Roles describe usage; they no longer select separate historical corner values.
var radiusRoles = ["control", "button", "tile", "action", "section", "panel",
    "header", "media", "navigation", "workspace", "tray", "field", "softCard",
    "compactControl", "appHighlight", "launcherGroup", "launcherGroupLarge",
    "tooltip", "previewLine", "insertionMarker"];
var shapeProfile = {edgeFraction: 1 / 5, controlHeightFraction: 1 / 3};

// Compositor preferences are already logical pixels and must not be rescaled.
var constraints = {
    borderThicknessDefault: 3, borderThicknessMinimum: 1,
    borderThicknessMaximum: 10, borderRadiusMaximum: 40,
    // Existing logical-pixel tolerances for resize suppression and edge approach.
    resizeEpsilon: 1, revealApproachInset: 2
};

var heightMetrics = {
    button: "buttonHeight", choice: "buttonHeight", switch: "switchHitHeight",
    slider: "sliderHeight", glassSlider: "glassHeight", glassSliderTrack: "glassSliderHeight", glass: "glassHeight",
    row: "rowHeight", quickSlider: "quickSliderHeight",
    // Tiles/cards historically receive their dimensions from their layout.
    tile: null, action: null
};

// Cubic Bezier approximation of a quarter circle; this is dimensionless.
var cubicCircleFactor = 0.5522847498307936;

function nonnegative(value) {
    return typeof value === "number" && isFinite(value) ? Math.max(0, value) : 0;
}

function positiveOr(value, fallback) {
    return typeof value === "number" && isFinite(value) && value > 0 ? value : fallback;
}

function scale(inputs) {
    inputs = inputs || {};
    var result = positiveOr(inputs.uiScale, 1)
        * positiveOr(inputs.fontSize, 13) / positiveOr(inputs.referenceFontSize, 13);
    return positiveOr(result, 1);
}

// Align static lengths once, before layout; animation ratios stay continuous.
function align(value, inputs) {
    inputs = inputs || {};
    var length = nonnegative(value);
    var ratio = positiveOr(inputs.devicePixelRatio, 1);
    var physical = length * ratio;
    return isFinite(physical) ? Math.round(physical) / ratio : length;
}

function scaledBaseline(baseline, inputs) {
    var result = baseline * scale(inputs);
    return isFinite(result) ? result : baseline;
}

function metric(name, inputs) {
    // Acyclic allocation relationships: these are never separate calibration inputs.
    if (name === "panelWindowWidth") return metric("launcherWidth", inputs) + 2 * metric("shoulderWidth", inputs);
    if (name === "revealWidth") return metric("pillWidth", inputs) + 2 * metric("shoulderWidth", inputs);
    if (name === "headerHeight") return Math.max(0, metric("pillHeight", inputs) - 2 * metric("headerInset", inputs));
    if (!Object.prototype.hasOwnProperty.call(calibration, name))
        throw new Error("Unknown geometry metric: " + name);
    return align(scaledBaseline(calibration[name], inputs), inputs);
}

function constraint(name) {
    if (!Object.prototype.hasOwnProperty.call(constraints, name))
        throw new Error("Unknown geometry constraint: " + name);
    return constraints[name];
}

function clamp(minimum, maximum, value) {
    var low = nonnegative(minimum);
    var high = Math.max(low, nonnegative(maximum));
    return Math.max(low, Math.min(high, nonnegative(value)));
}

function fit(preferred, available) {
    return Math.min(nonnegative(preferred), nonnegative(available));
}

function capsule(width, height) {
    return Math.min(nonnegative(width), nonnegative(height)) / 2;
}

// Use for user/platform preferences that are already logical-pixel inputs.
function boundedRadius(preferred, width, height) {
    return fit(preferred, capsule(width, height));
}

function radius(role, width, height, inputs) {
    if (radiusRoles.indexOf(role) === -1)
        throw new Error("Unknown geometry radius role: " + role);
    // Continuous final-box geometry: no per-feature radius calibration or rounding
    // feedback. Larger surfaces share a ceiling derived from control height.
    var edge = Math.min(nonnegative(width), nonnegative(height));
    return boundedRadius(Math.min(edge * shapeProfile.edgeFraction,
        metric("buttonHeight", inputs) * shapeProfile.controlHeightFraction), width, height);
}

// Circular inner contour: same center as its outer contour, bounded by its box.
function insetRadius(outer, inset, width, height) {
    return boundedRadius(Math.max(0, nonnegative(outer) - nonnegative(inset)), width, height);
}

// contentHeight includes any role-specific vertical padding supplied by callers.
function controlHeight(role, contentHeight, inputs) {
    if (!Object.prototype.hasOwnProperty.call(heightMetrics, role))
        throw new Error("Unknown geometry height role: " + role);
    var name = heightMetrics[role];
    return Math.max(name === null ? 0 : metric(name, inputs), nonnegative(contentHeight));
}

function stroke(focused, inputs) {
    inputs = inputs || {};
    // Existing one/two logical-pixel borders; never thinner than one device pixel.
    return Math.max(align(scaledBaseline(focused ? 2 : 1, inputs), inputs),
                    1 / positiveOr(inputs.devicePixelRatio, 1));
}

// Fallback icon surfaces belong to the same shape family as their surrounding UI.
function proportionalRadius(role, width, height, inputs) {
    if (["launcherIcon", "launcherIconDetail"].indexOf(role) === -1)
        throw new Error("Unknown proportional radius role: " + role);
    return radius("control", width, height, inputs);
}
// Radial menu allocations depend only on viewport and upstream calibrated lengths.
function wheelOuterRadius(width, height, inputs) {
    var available = Math.max(0, Math.min(
        nonnegative(width) - metric("wheelHorizontalReserve", inputs),
        nonnegative(height) - metric("wheelVerticalReserve", inputs))) / 2;
    return Math.min(available, metric("wheelMaximumRadius", inputs),
        Math.max(metric("wheelMinimumRadius", inputs), available));
}
function wheelInnerRadius(outer, inputs) {
    return nonnegative(outer) * 0.48;
}

// Per-output preference validation keeps independent screens independent.
function outputScale(values, name) {
    var value = values && values[name];
    return typeof value === "number" && isFinite(value) && value >= 1 && value <= 2 && Math.round(value * 4) === value * 4 ? value : 1;
}
