pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "core" as Core
import "components"
ShellRoot {
    id: fixture
    Core.SystemServices { id: services }
    property var pills: []
    Variants { model: Quickshell.screens; Pill {
        root: services
        Component.onCompleted: fixture.pills = fixture.pills.concat([this])
        Component.onDestruction: fixture.pills = fixture.pills.filter(p => p !== this)
    } }
    function find(item, predicate) {
        if (predicate(item)) return item;
        for (const child of item.children || []) { const match = find(child, predicate); if (match) return match; }
        return null;
    }
    function launcher() { return find(pills[0].contentItem, item => item.searchText !== undefined); }
    IpcHandler {
        target: "verify-launcher"
        function show(): void { fixture.pills[0].section = "launcher"; }
        function dismiss(): void { fixture.pills[0].dismiss(); }
        function query(text: string): void { fixture.launcher().searchText = text; }
        function preferences(value: string): void { services.setPreferences(JSON.parse(value)); }
        function recent(identity:string):void { const l=fixture.launcher(); l.recordRecent(l.savedApp(identity)); }
        function all(): void { fixture.launcher().showAll = true; fixture.launcher().focusSearch(); }
        function context(kind: string, identity: string): void {
            const l = fixture.launcher();
            l.openContext(kind, kind === "app" ? l.savedApp(identity) : null, kind === "group" ? services.preferences.appGroups.find(g => g.name === identity) : null, 380, 1000);
        }
        function state(): string {
            const l = fixture.launcher(), p = fixture.pills[0];
            const focus = p.contentItem.Window.window.activeFocusItem;
            const menu = fixture.find(l, item => item.objectName === "launcherContext");
            const grid = fixture.find(l, item => item.objectName === "launcherDragGrid");
            return JSON.stringify({section:p.section,width:p.surfaceWidth,height:p.surfaceHeight,targetHeight:p.targetHeight,busy:p.busy,current:l.currentIndex,selected:l.selectedEntry ? l.selectedEntry.id : null,home:l.homeEntries.map(e => e.key),recent:l.recentApps.map(a=>a.id),recentIds:l.recentIds,snap:l.snapPlacement,gridOpacity:grid.gridOpacity,snapX:grid.destinationX,snapY:grid.destinationY,homeViewport:fixture.find(l,item=>item.contentY!==undefined && item.contentHeight===l.totalHomeHeight).height,results:l.results.map(a => a.id),group:l.activeGroup,query:l.searchText,all:l.showAll,commandConfirmed:l.commandConfirmed,context:l.contextOpen,menuIndex:l.menuIndex,menu:l.contextEntries,menuBounds:{x:menu.x,y:menu.y,w:menu.width,h:menu.height,viewportW:l.width,viewportH:l.height},focus:focus ? focus.objectName : "",feedback:l.feedback,drag:!!l.dragSource,dragKey:l.dragSource ? l.dragSource.orderKey : "",dragPoint:{x:l.dragPoint.x,y:l.dragPoint.y},intent:l.dropIntent,prefs:services.preferences,exclusions:l.desktopExclusions,error:services.preferenceError,loaded:services.preferencesLoaded,creating:l.creatingGroup,deleteName:l.pendingDeleteName,menuScrollY:fixture.find(menu,item=>item.contentY !== undefined).contentY});
        }
        function surfaces():string { const l=fixture.launcher(),out=[]; function walk(item){if(item.orderKey){out.push({key:item.orderKey,panels:item.children.filter(child=>child.border!==undefined && child.visible && child.border.width>0).map(child=>({width:child.width,height:child.height,border:child.border.width}))});}for(const child of item.children||[])walk(child);}walk(l);return JSON.stringify(out); }
        function tiles(): string {
            const l = fixture.launcher(), out = [];
            function walk(item) {
                if (item.orderKey) { const p = item.mapToItem(fixture.pills[0].contentItem, 0, 0); out.push({key:item.orderKey,x:p.x,y:p.y,w:item.width,h:item.height}); }
                for (const child of item.children || []) walk(child);
            }
            walk(l); return JSON.stringify(out);
        }
        function icons(): string {
            const out = [];
            function walk(item) { if (item.iconName !== undefined) out.push({icon:item.iconName,ready:item.ready}); for (const child of item.children || []) walk(child); }
            walk(fixture.launcher()); return JSON.stringify(out);
        }
        function apps(): string {
            return JSON.stringify(services.sortedApps.map(a => ({id:a.id,name:a.name,icon:a.icon,resolved:Quickshell.iconPath(a.icon,true),terminal:a.runInTerminal,directory:a.workingDirectory})));
        }
    }
}
