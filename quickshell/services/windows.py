#!/usr/bin/env python3
"""Minimize/restore individual windows and toggle a reversible floating pin.

Restore brings the selected window to the focused monitor's current workspace,
so other monitors keep their independent workspace choices. Session-local state
preserves floating geometry and fullscreen/pin state; closed windows are pruned.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys

TRAY = "special:wizarch-tray"


def query(what):
    return json.loads(subprocess.check_output(["hyprctl", what, "-j"], text=True, timeout=3))


def dispatch(method, **params):
    # JSON strings are also Lua strings; booleans need Lua's spelling.
    def value(item):
        return str(item).lower() if isinstance(item, bool) else json.dumps(item, ensure_ascii=False)
    args = ", ".join(f"{key} = {value(item)}" for key, item in params.items())
    result = subprocess.check_output(["hyprctl", "dispatch", f"hl.dsp.{method}({{ {args} }})"], text=True, timeout=3)
    if result.strip() != "ok":
        raise RuntimeError(result.strip())


def selector(name):
    return name if name.isdigit() or name.startswith("special:") else "name:" + name


def identity(client):
    return [client.get("stableId"), client.get("pid")]


def prune(state, clients):
    live = {client["address"]: client for client in clients}
    for kind in ("minimized", "popped"):
        state.setdefault(kind, {})
        state[kind] = {address: record for address, record in state[kind].items()
                       if address in live and record["identity"] == identity(live[address])
                       and (kind != "minimized" or live[address]["workspace"]["name"] == TRAY)}


def snapshot(client, monitors):
    monitor = next((m for m in monitors if m["id"] == client["monitor"]), monitors[0])
    return {"identity": identity(client), "floating": client["floating"], "pinned": client["pinned"],
            "fullscreen": client["fullscreen"], "fullscreenClient": client["fullscreenClient"],
            "size": client["size"], "offset": [client["at"][0] - monitor["x"], client["at"][1] - monitor["y"]]}


def floating_geometry(record, monitor):
    width, height = monitor["width"] / monitor["scale"], monitor["height"] / monitor["scale"]
    if monitor.get("transform", 0) % 2:
        width, height = height, width
    left, top, right, bottom = monitor.get("reserved", [0, 0, 0, 0])
    width, height = max(1, int(width - left - right)), max(1, int(height - top - bottom))
    size = [min(record["size"][0], width), min(record["size"][1], height)]
    x = monitor["x"] + min(max(record["offset"][0], left), left + width - size[0])
    y = monitor["y"] + min(max(record["offset"][1], top), top + height - size[1])
    return size, [int(x), int(y)]


def apply_appearance(client, record, monitor):
    window = "address:" + client["address"]
    dispatch("window.float", window=window, action="on" if record["floating"] else "off")
    if record["floating"]:
        size, at = floating_geometry(record, monitor)
        dispatch("window.resize", window=window, x=size[0], y=size[1], relative=False)
        dispatch("window.move", window=window, x=at[0], y=at[1], relative=False)
    dispatch("window.fullscreen_state", window=window, action="set", internal=record["fullscreen"], client=record["fullscreenClient"])
    # Hyprland rejects even an unset pin request for an already tiled window.
    if record["floating"]:
        dispatch("window.pin", window=window, action="on" if record["pinned"] else "off")


class Controls:
    def __init__(self, path):
        self.path = path
        self.state = json.loads(path.read_text()) if path.exists() else {}
        self.clients = query("clients")
        self.monitors = query("monitors")
        if not self.monitors:
            raise RuntimeError("No active monitors")
        prune(self.state, self.clients)

    def save(self):
        temporary = self.path.with_suffix(".tmp")
        temporary.write_text(json.dumps(self.state))
        temporary.replace(self.path)

    def active(self, address=None):
        address = address or query("activewindow").get("address")
        client = next((c for c in self.clients if c["address"] == address), None)
        if client and client.get("mapped") and not client["workspace"]["name"].startswith("special:"):
            return client
        return None

    def minimize(self, address=None):
        client = self.active(address)
        if not client:
            return
        address = client["address"]
        self.state["minimized"][address] = snapshot(client, self.monitors)
        self.save()  # Keep recovery information if a later dispatch fails.
        window = "address:" + address
        if client["pinned"]:
            dispatch("window.pin", window=window, action="off")
        dispatch("window.fullscreen_state", window=window, action="set", internal=0, client=0)
        dispatch("window.move", window=window, workspace=TRAY, follow=False)

    def restore(self, address=None):
        tray = {c["address"]: c for c in self.clients if c["workspace"]["name"] == TRAY}
        if address is None:
            address = next((a for a in reversed(self.state["minimized"]) if a in tray), None)
            if address is None and tray:
                address = min(tray, key=lambda a: tray[a].get("focusHistoryID", 0))
        client = tray.get(address)
        if not client:
            return
        monitor = next((m for m in self.monitors if m["focused"]), self.monitors[0])
        workspace = monitor["activeWorkspace"]["name"]
        window = "address:" + address
        dispatch("window.move", window=window, workspace=selector(workspace), follow=False)
        record = self.state["minimized"].get(address)
        if record:
            apply_appearance(client, record, monitor)
        dispatch("focus", window=window)
        self.state["minimized"].pop(address, None)

    def pop(self, address=None):
        client = self.active(address)
        if not client:
            return
        address, window = client["address"], "address:" + client["address"]
        monitor = next((m for m in self.monitors if m["id"] == client["monitor"]), self.monitors[0])
        record = self.state["popped"].get(address)
        if client["pinned"] or record:
            if client["pinned"]:
                dispatch("window.pin", window=window, action="off")
            if record:
                apply_appearance(client, record, monitor)
                self.state["popped"].pop(address, None)
            return
        self.state["popped"][address] = snapshot(client, self.monitors)
        self.save()
        dispatch("window.fullscreen_state", window=window, action="set", internal=0, client=0)
        dispatch("window.float", window=window, action="on")
        # Bound the popup to the current monitor, including rotated/scaled displays.
        bounds, _ = floating_geometry({"size": [100000, 100000], "offset": [0, 0]}, monitor)
        dispatch("window.resize", window=window, x=min(1300, int(bounds[0] * .7)), y=min(900, int(bounds[1] * .8)), relative=False)
        dispatch("window.center", window=window)
        dispatch("window.pin", window=window, action="on")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("minimize", "restore", "pop"))
    parser.add_argument("address", nargs="?")
    args = parser.parse_args()
    if args.address and not re.fullmatch(r"0x[0-9a-fA-F]+", args.address):
        parser.error("Expected a hexadecimal window address")
    key = re.sub(r"[^a-zA-Z0-9_-]", "_", os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "session"))
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if runtime:
        runtime_path = Path(runtime)
    elif Path(f"/run/user/{os.getuid()}").is_dir() and os.access(f"/run/user/{os.getuid()}", os.W_OK):
        runtime_path = Path(f"/run/user/{os.getuid()}")
    else:
        runtime_path = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "wizarch" / "run"
    runtime_path.mkdir(parents=True, exist_ok=True)
    path = runtime_path / ("wizarch-windows-" + key + ".json")
    with path.with_suffix(".lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        controls = Controls(path)
        getattr(controls, args.action)(args.address)
        controls.save()


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(json.dumps({"error": str(error)}), file=sys.stderr)
        sys.exit(1)
