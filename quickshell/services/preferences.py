#!/usr/bin/env python3
"""Small atomic store for user shell preferences."""
import json
import os
import fcntl
from pathlib import Path
import sys
import re
from datetime import date

PATH = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "wizarch" / "preferences.json"
DEFAULTS = {"uiScaleByOutput": {},"audioMode": "sound", "notificationSounds": True, "systemVolume": 55, "dnd": False,
            "alertPattern": "single", "pinnedApps": [], "appGroups": [], "launcherOrder": [], "hiddenApps": [], "edgeConnected": True, "screenBorder": False, "borderThickness": 3, "borderRadius": 12, "autoHide": False, "hideOnEmptyMonitor": False, "revealMode": "push", "matchWindowCorners": True, "windowSpacing": 75, "calendarPrimary": "gregorian", "calendarSecondary": "solar", "calendarWeekStart": "auto", "calendarEvents": []}


ENUMS = {"audioMode": {"sound","alert","mute"}, "alertPattern": {"single","double","triple"}, "revealMode": {"push","overlay"}, "calendarPrimary": {"gregorian","solar"}, "calendarSecondary": {"off","gregorian","solar"}, "calendarWeekStart": {"auto","saturday","monday","sunday"}}
BOUNDS = {"systemVolume": (0,100), "borderThickness": (1,10), "borderRadius": (0,40), "windowSpacing": (0,100)}
def valid(key,value):
    if key not in DEFAULTS or type(value) is not type(DEFAULTS[key]): return False
    if key == "uiScaleByOutput":
        return len(value) <= 32 and all(isinstance(name,str) and 1 <= len(name) <= 128 and type(scale) in (int,float) and 1 <= scale <= 2 and scale*4 == round(scale*4) for name,scale in value.items())
    if key in ENUMS and value not in ENUMS[key]: return False
    if key in BOUNDS and not BOUNDS[key][0] <= value <= BOUNDS[key][1]: return False
    if key == "calendarEvents":
        if len(value) > 500: return False
        ids = set()
        for event in value:
            if not isinstance(event, dict) or set(event) != {"id","date","title","color","icon"}: return False
            if any(not isinstance(event[k], str) for k in event): return False
            if not 1 <= len(event["id"]) <= 80 or event["id"] in ids: return False
            ids.add(event["id"])
            if not 1 <= len(event["title"].strip()) <= 100 or len(event["icon"]) > 8: return False
            if event["color"] and not re.fullmatch(r"#[0-9a-fA-F]{6}",event["color"]): return False
            try:
                if not re.fullmatch(r"\d{4}-\d{2}-\d{2}",event["date"]): return False
                if not date(1901,1,1) <= date.fromisoformat(event["date"]) <= date(2099,12,31): return False
            except ValueError: return False
    return True


def normalize(data):
    if data["calendarPrimary"] == data["calendarSecondary"]: data["calendarSecondary"] = "off"
    return data


def read():
    try:
        data = json.loads(PATH.read_text())
        return normalize({**DEFAULTS, **{k:v for k,v in data.items() if k not in DEFAULTS or valid(k,v) or (k=="revealMode" and v=="wallpaper")}}) if isinstance(data, dict) else DEFAULTS.copy()
    except (OSError, ValueError):
        return DEFAULTS.copy()


def write(data):
    normalize(data)
    PATH.parent.mkdir(parents=True, exist_ok=True)
    temp = PATH.with_suffix(".tmp")
    temp.write_text(json.dumps(data, indent=2) + "\n")
    os.replace(temp, PATH)


if __name__ == "__main__":
    PATH.parent.mkdir(parents=True, exist_ok=True)
    with PATH.with_suffix(".lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        data = read()
        if data.get("revealMode") == "wallpaper":
            data["revealMode"] = "overlay"
            write(data)
        if len(sys.argv) == 4 and sys.argv[1] == "set" and sys.argv[2] in DEFAULTS:
            key = sys.argv[2]
            value = json.loads(sys.argv[3])
            if not valid(key,value):
                raise SystemExit("wrong value type")
            data[key] = value
            write(data)
        elif len(sys.argv) == 3 and sys.argv[1] == "merge":
            changes = json.loads(sys.argv[2])
            if not isinstance(changes, dict) or any(not valid(k,v) for k, v in changes.items()):
                raise SystemExit("invalid preference update")
            data.update(changes)
            write(data)
        elif len(sys.argv) != 1:
            raise SystemExit("usage: preferences.py [set KEY JSON_VALUE] | [merge JSON_OBJECT]")
    print(json.dumps(data))
