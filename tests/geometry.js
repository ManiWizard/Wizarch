// Run with Node; loads the same pure model imported by the QML singleton.
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert');
const modelPath = process.argv[2] || path.join(__dirname, '../quickshell/core/Geometry.js');
const model = {};
vm.createContext(model);
vm.runInContext(fs.readFileSync(modelPath, 'utf8').replace(/^\.pragma library\s*/m, ''), model);
let checks = 0;
function near(actual, expected, message) {
    checks++;
    assert(Number.isFinite(actual) && Math.abs(actual - expected) < 1e-9,
           `${message}: ${actual} != ${expected}`);
}
const defaults = {buttonHeight:38, buttonPadding:13, switchWidth:50, switchHitHeight:32,
    switchTrackHeight:28, switchInset:3, sliderHandle:20, settingsTrack:6, quickTrack:8,
    sliderHeight:32, glassSliderHeight:30, glassHeight:58, rowHeight:58, sectionPadding:18,
    sectionGap:12, contentGap:8, quickSliderHeight:44, quickSliderGap:8, pillWidth:194,
    pillHeight:42, panelWidth:360, launcherWidth:420, panelWindowWidth:484,
    revealWidth:258, revealHeight:3, shoulderWidth:32, shoulderHeight:28,
    workspaceWidth:18, workspaceHeight:28, workspaceGap:2};
for (const [name, expected] of Object.entries(defaults)) near(model.metric(name), expected, name);
const radii=Object.fromEntries(model.radiusRoles.map(role=>[role,38/3]));
for(const [role,radius] of Object.entries(radii))near(model.radius(role,1000,1000),radius,role);
for(const [role,height] of Object.entries({button:38,choice:38,switch:32,slider:32,glassSlider:58,glassSliderTrack:30,row:58,quickSlider:44,tile:0,action:0})) {
    near(model.controlHeight(role,0),height,role+' default height');
    near(model.controlHeight(role,101),101,role+' content growth');
}
for (const scale of [0.5,1,1.25,2]) for (const fontSize of [10,13,20]) for (const dpr of [1,1.25,2,3]) {
    const inputs={uiScale:scale,fontSize,devicePixelRatio:dpr};
    const aligned = base => Math.round(base*scale*fontSize/13*dpr)/dpr;
    for (const [name, base] of Object.entries(defaults)) {
        const expected = name === 'panelWindowWidth' ? aligned(420) + 2*aligned(32)
            : name === 'revealWidth' ? aligned(194) + 2*aligned(32) : aligned(base);
        near(model.metric(name,inputs),expected,`${name} scaled`);
    }
    near(model.metric('headerHeight',inputs),Math.max(0,aligned(42)-2*aligned(4)),'header allocation');
    // Preferred lengths align to physical pixels; tiny fills remain bounded.
    for (const [width,height] of [[0,6],[0.2,6],[1.6,8],[44,44],[160,44],[8,160]]) {
        near(model.capsule(width,height),Math.min(width,height)/2,'capsule');
        for(const [role,base] of Object.entries(radii))near(model.radius(role,width,height,inputs),Math.min(Math.min(width,height)/5,aligned(38)/3),'bounded '+role);
        near(model.insetRadius(22,3,width,height),Math.min(19,width/2,height/2),'concentric inset');
    }
    near(model.stroke(false,inputs),Math.max(Math.round(scale*fontSize/13*dpr)/dpr,1/dpr),'normal border');
    near(model.stroke(true,inputs),Math.max(Math.round(2*scale*fontSize/13*dpr)/dpr,1/dpr),'focused border');
}
near(model.capsule(44,44),22,'action circle');
near(model.insetRadius(14,3,22,22),11,'switch thumb circle');
near(model.insetRadius(9,20,12,12),0,'collapsed inner contour');
near(model.fit(100,20),20,'constrained available span');
near(model.fit(20,100),20,'preferred span');
near(model.clamp(2,10,100),10,'upper clamp');
near(model.clamp(2,10,-1),2,'lower clamp');
for(const bad of [-1,NaN,Infinity,undefined]) {
    near(model.capsule(bad,44),0,'invalid bound');
    near(model.boundedRadius(bad,44,44),0,'invalid preferred radius');
}
near(model.scale({uiScale:-1,fontSize:NaN,referenceFontSize:0}),1,'invalid scale defaults');
for(const invocation of [()=>model.metric('absent'),()=>model.radius('absent',10,10),()=>model.controlHeight('absent',10)]) {
    checks++;assert.throws(invocation,/Unknown geometry/);
}
console.log(`GEOMETRY_MODEL_PASS: ${checks} checks; layout calibration, unified corners and mathematical bounds, content growth, scale/font/DPR determinism`);
// Cover every semantic role and proportional silhouette, including invisible/zero-size items.
for (const inputs of [{},{uiScale:1.25,fontSize:20,devicePixelRatio:1.5}]) {
    for (const [role,preferred] of Object.entries(radii)) {
        for (const [width,height] of [[0,0],[1,2],[3,100],[28,28],[70,70],[160,88]]) {
            const result=model.radius(role,width,height,inputs);
            checks++;
            assert(result>=0 && result<=Math.min(width,height)/2,`${role} respects rendered box`);
        }
        near(model.radius(role,1000,1000),preferred,`${role} default appearance`);
    }
    for (const [role,data] of Object.entries({launcherIcon:0,launcherIconDetail:0})) {
        for (const [width,height] of [[0,0],[1,2],[28,28],[70,70],[120,50]]) {
            const result=model.proportionalRadius(role,width,height,inputs);
            checks++;
            assert(result>=0 && result<=Math.min(width,height)/2,`${role} proportional bounds`);
        }
    }
}
near(model.proportionalRadius('launcherIcon',70,70),38/3,'fallback icon uses shared profile');
near(model.proportionalRadius('launcherIconDetail',44.8,42),42/5,'fallback icon detail uses shared profile');
near(model.wheelOuterRadius(1920,1080),200,'wheel viewport baseline');
near(model.wheelInnerRadius(200),96,'wheel dead zone baseline');
near(model.wheelOuterRadius(0,0),0,'wheel zero viewport');
near(model.wheelOuterRadius(100,200),26,'wheel narrow viewport');
console.log(`GEOMETRY_ALL_ROLES_PASS: ${checks} total checks`);

for (const [width,height] of [[30,30],[44,44],[70,70],[186,174]]) {
    const shape=model.radius('control',width,height);
    assert(shape < model.capsule(width,height), 'interactive surface must not become a circle/capsule');
    for (const role of model.radiusRoles) near(model.radius(role,width,height),shape,role+' shared silhouette');
}
console.log(`UNIFIED_SHAPE_PASS: ${checks} assertions; old per-feature radii removed`);

for (const scale of [1,1.25,1.5,1.75,2]) near(model.outputScale({"HDMI-A-1":scale}, "HDMI-A-1"),scale,"output scale");
for (const scale of [0,3,1.1,NaN,Infinity,"2",true]) near(model.outputScale({"HDMI-A-1":scale}, "HDMI-A-1"),1,"invalid output scale");
near(model.outputScale({"HDMI-A-1":2},"eDP-1"),1,"independent output default");
console.log("OUTPUT_SCALE_PASS");
