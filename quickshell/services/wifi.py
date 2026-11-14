#!/usr/bin/env python3
"""List and connect NetworkManager Wi-Fi access points without shell interpolation."""
import json
import shutil
import subprocess
import sys


def run(args):
    return subprocess.run(args, text=True, capture_output=True, timeout=20, check=True).stdout


try:
    if not shutil.which("nmcli"):
        raise RuntimeError("Install and enable NetworkManager to browse Wi-Fi networks")
    if len(sys.argv) == 1 or sys.argv[1] == "list":
        output = run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "auto"])
        networks = []
        seen = set()
        for line in output.splitlines():
            parts = line.replace("\\:", "\u0000").split(":")
            if len(parts) < 4:
                continue
            active, ssid, signal, security = [p.replace("\u0000", ":") for p in parts[:4]]
            if not ssid or ssid in seen:
                continue
            seen.add(ssid)
            networks.append({"ssid": ssid, "signal": signal, "security": security,
                             "connected": active == "*"})
        print(json.dumps({"ok": True, "networks": networks}))
    elif sys.argv[1] == "connect" and len(sys.argv) in (3, 4):
        command = ["nmcli", "device", "wifi", "connect", sys.argv[2]]
        if len(sys.argv) == 4 and sys.argv[3]:
            command.extend(["password", sys.argv[3]])
        run(command)
        print(json.dumps({"ok": True}))
    else:
        raise ValueError("Invalid Wi-Fi action")
except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
    print(json.dumps({"ok": False, "error": str(error)}))
    sys.exit(1)
