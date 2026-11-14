"""Real MediaCard with isolated MPRIS mocks; never touches actual playback."""
from pathlib import Path
import os, re, runpy, select, shutil, subprocess, sys, tempfile, time
src=Path(__file__).resolve().parents[1]/'quickshell'
out=Path('/home/Mw/ChatGPT/Wizarch Shell/audit/media-20261009');out.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='wizarch-media-') as temp:
 folder=Path(temp)
 for d in ['components','core']:(folder/d).mkdir()
 for name in ['MediaCard','Glyph','ThemedToolTip']:shutil.copy2(src/'components'/f'{name}.qml',folder/'components')
 shutil.copy2(src/'core/MediaMetadata.js',folder/'core')
 shutil.copytree(src/'assets',folder/'assets')
 runpy.run_path(str(src.parent/'tests/theme-fixture.py'))['write_theme'](folder,src)
 (folder/'core/qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Geometry 1.0 Geometry.qml\nGeometryContext 1.0 GeometryContext.qml\n')
 (folder/'art.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="600" height="400"><rect width="600" height="400" fill="#fefefe"/><circle cx="400" cy="100" r="190" fill="#102070"/><path d="M0 400L600 0" stroke="#ff6000" stroke-width="120"/></svg>')
 qml='''pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import "components"
import "core" as Core
ShellRoot {
 id:f
 QtObject {
  id:p
  property var metadata: ({"xesam:url":"file:///song.flac"})
  property string trackArtUrl: Qt.resolvedUrl("art.svg")
  property string desktopEntry:"kitty"
  property string identity:"Fixture player"
  property string trackTitle:"A very long media title that must stay inside the card and elide cleanly"
  property string trackArtist:"Artist / creator"
  property bool isPlaying:true
  property bool lengthSupported:true
  property bool positionSupported:true
  property real length:245
  property real position:65
  property bool canSeek:true
  property bool canControl:true
  property bool canPause:true
  property bool canPlay:true
  property bool canGoPrevious:true
  property bool canGoNext:true
  property bool shuffleSupported:true
  property bool shuffle:false
  property int ticks:0
  property var calls:[]
  onPositionChanged:ticks++
  function previous(){calls=calls.concat(["previous"]);}
  function next(){calls=calls.concat(["next"]);}
  function pause(){isPlaying=false;calls=calls.concat(["pause"]);}
  function play(){isPlaying=true;calls=calls.concat(["play"]);}
 }
 QtObject { id:adapter;property bool liked:false;function supports(player){return player===p;}function isFavorite(player){return liked;}function toggle(player){liked=!liked;} }
 FloatingWindow {
  visible:true;implicitWidth:360;implicitHeight:card.height+36;color:Core.Theme.surfaceContainerLow
  TestCase {id:input;name:"MediaInput";when:false}
  MediaCard {id:card;x:18;y:18;width:324;player:p}
 }
 function expect(ok,label){if(!ok)throw new Error(label);}
 function find(item,name){if(item.objectName===name)return item;for(let c of item.children||[]){let r=find(c,name);if(r)return r;}return null;}
 function named(name){return find(card,name);}
 function geometry(){
  let play=named("media-play");
  if(play && play.visible) expect(play.background.radius<Math.min(play.width,play.height)*.4,"play follows new noncircular shape family");
  expect(card.height===166,"compact height");
  expect(named("mediaElapsed").font.pixelSize===10 && named("mediaDuration").font.pixelSize===10,"unchanged time font sizes");
  expect(named("mediaTitle").font.pixelSize===14 && named("mediaArtist").font.pixelSize===11,"smaller text");
  expect(!named("mediaOutputToggle"),"no output toggle");
  let title=named("mediaTitle"),artist=named("mediaArtist"),slider=named("mediaProgress"),elapsed=named("mediaElapsed");
  expect(title.y+title.height<=artist.y && artist.y+artist.height<=slider.y && slider.y+slider.height<=elapsed.y,"text and progress do not overlap");
  for(let name of ["shuffle","previous","play","next","favorite"]){let button=named("media-"+name);if(button.visible){let point=button.mapToItem(card,0,0);expect(point.x>=0 && point.y>=elapsed.y+elapsed.height && point.x+button.width<=card.width && point.y+button.height<=card.height,"controls fit "+name);expect(button.width===38 && button.height===40,"preserved input area");}}
 }
 property int phase:0
 property bool busy:false
 function capture(name){busy=true;card.grabToImage(r=>{expect(r.saveToFile("OUTPUT/"+name+".png"),"capture");busy=false;phase++;});}
 Timer {interval:350;repeat:true;running:true;onTriggered:{
  if(f.busy)return;
  try {
   let shuffle=f.named("media-shuffle"),prev=f.named("media-previous"),play=f.named("media-play"),next=f.named("media-next"),fav=f.named("media-favorite"),slider=f.named("mediaProgress");
   if(f.phase===0){f.geometry();f.expect(card.mediaKind==="music" && shuffle.visible,"music classified");f.expect(!fav.visible,"no fabricated favorite");f.expect(card.artworkReady,"art loaded");f.expect(f.named("mediaElapsed").text==="1:05" && f.named("mediaDuration").text==="4:05","seconds formatted");f.expect(slider.enabled && slider.value===65,"seek capability");f.expect(card.desktopApp && card.appName===card.desktopApp.name,"desktop identity");f.capture("music-dark");}
   else if(f.phase===1){shuffle.activate();prev.activate();play.activate();play.activate();next.activate();f.expect(p.shuffle && JSON.stringify(p.calls)==='["previous","pause","play","next"]',"real capability dispatch");f.expect(p.ticks>0,"playing position polled");card.favoriteAdapter=adapter;card.width=264;f.geometry();card.width=324;f.expect(fav.visible,"genuine adapter exposed");fav.activate();f.expect(adapter.liked,"adapter dispatched");p.metadata={"xesam:url":"file:///movie.webm"};f.phase++;}
   else if(f.phase===2){f.geometry();f.expect(card.mediaKind==="video" && !shuffle.visible && !fav.visible,"video never music controls");let calls=p.calls.length;shuffle.activate();fav.activate();f.expect(p.calls.length===calls && adapter.liked,"hidden controls refuse activation");f.capture("video-dark");}
   else if(f.phase===3){p.metadata={"xesam:url":"https://example.com/watch?id=123"};p.identity="Browser";p.desktopEntry="";f.expect(card.mediaKind==="unknown" && !shuffle.visible && !fav.visible,"ambiguous browser conservative");f.expect(card.appName==="Browser","identity fallback");card.mediaKindOverride="music";f.expect(shuffle.visible,"explicit override");card.mediaKindOverride="";p.canGoNext=false;p.canGoPrevious=false;p.canPause=false;f.expect(!prev.visible && !next.visible && !play.visible,"unsupported controls hidden");p.canPause=true;p.canControl=false;f.expect(!play.enabled && !play.activeFocusOnTab && !slider.enabled,"read-only player");let before=p.calls.length;play.activate();f.expect(p.calls.length===before,"disabled dispatch refused");p.canControl=true;p.lengthSupported=false;p.positionSupported=false;f.expect(!slider.enabled && f.named("mediaDuration").text==="—:—" && f.named("mediaElapsed").text==="—:—","unknown duration/position");p.trackArtUrl="";f.capture("missing-art-live");}
   else if(f.phase===4){f.expect(!card.artworkReady,"missing artwork fallback");p.metadata={"mpris:contentType":"video/mp4"};p.lengthSupported=true;p.positionSupported=true;p.canGoNext=true;p.canGoPrevious=true;p.trackArtUrl=Qt.resolvedUrl("art.svg");p.length=3700;p.position=3601;Core.Theme.mode="light";Core.Theme.palette=LIGHT;f.phase++;}
   else if(f.phase===5){f.geometry();f.expect(f.named("mediaElapsed").text==="1:00:01" && f.named("mediaDuration").text==="1:01:40","hour times");f.capture("video-light");}
   else if(f.phase===6){slider.forceActiveFocus();let before=p.position;input.keyClick(Qt.Key_Right);f.expect(p.position>before,"keyboard seek writes " + slider.value + " / " + p.position);play.forceActiveFocus();let calls=p.calls.length;input.keyClick(Qt.Key_Space);f.expect(p.calls.length===calls+1,"keyboard playback");card.width=264;p.trackArtUrl="file:///nonexistent-wizarch-art.png";f.phase++;}
   else if(f.phase===7){f.geometry();f.expect(!card.artworkReady && f.named("mediaTitle").width===236,"broken artwork and bounded narrow title");f.capture("narrow-fallback");}
   else if(f.phase===8){card.player=null;f.expect(!slider.enabled && !play.visible && card.appName==="Media player","selected player removed");console.log("MEDIA_CARD_PASS: music/video/unknown, adapter gating, capability dispatch, seek/keyboard, identity, live/unknown time, artwork, light/dark, narrow/compact geometry, polling, player removal");f.phase++;}
  }catch(e){console.error("MEDIA_CARD_FAIL: "+e);f.phase=100;}
 }}
}
'''.replace('OUTPUT',str(out))
 import json
 light=json.loads((src/'themes/wizarch/colors.json').read_text())['schemes']['light']
 qml=qml.replace('LIGHT',json.dumps(light))
 (folder/'shell.qml').write_text(qml)
 proc=subprocess.Popen(['quickshell','-p',str(folder),'--no-color'],env=dict(os.environ,QT_QPA_PLATFORM='wayland' if '--wayland' in sys.argv else 'offscreen',XDG_CONFIG_HOME=str(folder/'config')),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 lines=[]
 try:
  deadline=time.monotonic()+15
  while time.monotonic()<deadline:
   if select.select([proc.stdout],[],[],0.2)[0]:
    line=proc.stdout.readline();lines.append(line)
    if 'MEDIA_CARD_PASS:' in line or 'MEDIA_CARD_FAIL:' in line:break
   if proc.poll() is not None:break
  print(''.join(lines))
  assert any('MEDIA_CARD_PASS:' in line for line in lines),'Media QML integration failed'
  assert not any(re.search(r'(ReferenceError|TypeError|Unable to assign|Binding loop|Cannot assign)',line) for line in lines),'QML runtime error'
 finally:proc.terminate();proc.wait(timeout=3)
