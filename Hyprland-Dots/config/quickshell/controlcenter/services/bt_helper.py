#!/usr/bin/env python3
import sys
import subprocess
import json

def get_status(scan=False):
    try:
        show_out = subprocess.getoutput("bluetoothctl show")
        powered = "Powered: yes" in show_out
    except Exception:
        powered = False

    if not powered:
        return {"powered": False, "paired": [], "available": []}

    if scan:
        try:
            subprocess.run(["bluetoothctl", "--timeout", "3", "scan", "on"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    paired_macs = set()
    paired = []
    try:
        paired_out = subprocess.getoutput("bluetoothctl devices Paired")
        for line in paired_out.splitlines():
            line = line.strip()
            if line.startswith("Device "):
                parts = line.split(" ", 2)
                if len(parts) >= 3:
                    mac, name = parts[1], parts[2]
                    paired_macs.add(mac)
                    info = subprocess.getoutput(f"bluetoothctl info {mac}")
                    connected = "Connected: yes" in info
                    paired.append({
                        "mac": mac,
                        "name": name,
                        "connected": connected
                    })
    except Exception:
        pass

    available = []
    try:
        all_out = subprocess.getoutput("bluetoothctl devices")
        for line in all_out.splitlines():
            line = line.strip()
            if line.startswith("Device "):
                parts = line.split(" ", 2)
                if len(parts) >= 3:
                    mac, name = parts[1], parts[2]
                    if mac not in paired_macs and not name.replace(":", "-").startswith("Device"):
                        available.append({"mac": mac, "name": name})
    except Exception:
        pass

    return {
        "powered": powered,
        "paired": paired,
        "available": available[:12]
    }

def toggle_power():
    show_out = subprocess.getoutput("bluetoothctl show")
    if "Powered: yes" in show_out:
        subprocess.run(["bluetoothctl", "power", "off"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        subprocess.run(["bluetoothctl", "power", "on"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return get_status()

def connect_device(mac):
    subprocess.run(["bluetoothctl", "connect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return get_status()

def disconnect_device(mac):
    subprocess.run(["bluetoothctl", "disconnect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return get_status()

def pair_device(mac):
    subprocess.run(["bluetoothctl", "pair", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["bluetoothctl", "connect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return get_status()

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    res = {}
    if cmd == "status":
        res = get_status(False)
    elif cmd == "scan":
        res = get_status(True)
    elif cmd == "toggle":
        res = toggle_power()
    elif cmd == "connect" and len(sys.argv) > 2:
        res = connect_device(sys.argv[2])
    elif cmd == "disconnect" and len(sys.argv) > 2:
        res = disconnect_device(sys.argv[2])
    elif cmd == "pair" and len(sys.argv) > 2:
        res = pair_device(sys.argv[2])
    else:
        res = get_status(False)

    print(json.dumps(res))

if __name__ == "__main__":
    main()
