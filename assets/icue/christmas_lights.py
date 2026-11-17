import argparse
import math
import os
import random
import signal
import sys
import time

from cuesdk import (CorsairAccessLevel, CorsairDeviceFilter, CorsairDeviceType, CorsairError,
                    CorsairLedColor, CorsairSessionState, CueSdk)

FPS = 30
RESCAN_SECONDS = 8
TWINKLE = [(255, 170, 20), (255, 255, 255), (255, 20, 20), (0, 255, 70), (255, 90, 160)]
CANDY = [(255, 10, 20), (255, 10, 20), (255, 235, 220), (255, 235, 220), (0, 190, 50), (0, 190, 50)]


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def add(base, extra, k):
    return tuple(min(255, int(base[i] + extra[i] * k)) for i in range(3))


def scale(color, k):
    return tuple(max(0, min(255, int(c * k))) for c in color)


GRID_TYPES = {"Keyboard", "GameController", "Touchbar"}
LINEAR_TYPES = {"MemoryModule", "Cooler", "FanLedController", "LedController", "Mousemat", "Mouse", "Headset",
                "HeadsetStand", "Motherboard", "GraphicsCard"}


def build_layout(positions, kind=""):
    if not positions:
        return [], "none"
    xs = [p.cx for p in positions]
    ys = [p.cy for p in positions]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    span_x, span_y = x1 - x0, y1 - y0
    long_axis, short_axis = max(span_x, span_y), min(span_x, span_y)
    two_d = len(positions) >= 24 and long_axis > 0 and short_axis > 0.22 * long_axis
    if kind in GRID_TYPES:
        mode = "grid" if long_axis > 0 else "linear"
    elif kind in LINEAR_TYPES:
        mode = "linear"
    else:
        mode = "grid" if two_d and len(positions) >= 60 else "linear"
    if long_axis <= 0:
        ordered = sorted(positions, key=lambda p: p.id)
    elif span_x >= span_y:
        ordered = sorted(positions, key=lambda p: (p.cx, p.cy, p.id))
    else:
        ordered = sorted(positions, key=lambda p: (p.cy, p.cx, p.id))
    rank = {p.id: i for i, p in enumerate(ordered)}
    leds = []
    for p in positions:
        nx = (p.cx - x0) / (span_x or 1)
        ny = (p.cy - y0) / (span_y or 1)
        leds.append((p.id, nx, ny, rank[p.id]))
    return leds, mode


class Effect:
    def __init__(self, info, leds, mode, brightness):
        self.info = info
        self.leds = leds
        self.mode = mode
        self.brightness = brightness
        self.flares = {}
        self.snow = [{"x": random.random(), "y": -random.random(), "v": 0.25 + random.random() * 0.4} for _ in range(7)]
        self.rate = max(0.2, min(0.7, len(leds) / 180.0))

    def frame(self, t, now, dt):
        if self.mode == "grid":
            colors = self.grid(t, now, dt)
        else:
            colors = self.linear(t, now)
        return [CorsairLedColor(lid, *scale(c, self.brightness), 255) for lid, c in colors]

    def grid(self, t, now, dt):
        for f in self.snow:
            f["y"] += f["v"] * dt
            if f["y"] > 1.15:
                f["x"], f["y"], f["v"] = random.random(), -0.1, 0.25 + random.random() * 0.4
        if random.random() < self.rate:
            lid = random.choice(self.leds)[0]
            self.flares[lid] = (random.choice(TWINKLE), now)
        out = []
        for lid, x, y, _ in self.leds:
            s = 0.5 + 0.5 * math.sin(2 * math.pi * (x * 1.6 - t * 0.10))
            c = lerp((70, 0, 4), (0, 55, 14), s)
            flare = self.flares.get(lid)
            if flare:
                k = max(0.0, 1.0 - (now - flare[1]))
                if k <= 0:
                    self.flares.pop(lid, None)
                else:
                    c = add(c, flare[0], k)
            for f in self.snow:
                d = math.hypot((x - f["x"]) * 1.5, y - f["y"])
                if d < 0.11:
                    c = add(c, (255, 255, 255), (1 - d / 0.11) * 0.9)
            out.append((lid, c))
        return out

    def linear(self, t, now):
        shift = int(t * 5)
        count = len(self.leds)
        out = []
        for lid, _, _, rank in self.leds:
            if count <= 6:
                c = (255, 10, 20) if (rank + shift // 2) % 2 == 0 else (0, 190, 50)
            else:
                c = CANDY[(rank + shift) % 6]
            if random.random() < 0.015:
                c = (255, 170, 20)
            out.append((lid, c))
        return out


def list_devices(sdk):
    devices, _ = sdk.get_devices(CorsairDeviceFilter(device_type_mask=CorsairDeviceType.CDT_All))
    return devices or []


def type_name(info):
    return str(info.type).replace("CorsairDeviceType.CDT_", "")


def make_effect(sdk, info, brightness):
    positions, _ = sdk.get_led_positions(info.device_id)
    leds, mode = build_layout(positions or [], type_name(info))
    if not leds:
        return None
    return Effect(info, leds, mode, brightness)


def connect(timeout=25):
    state = {"s": None}
    sdk = CueSdk()
    sdk.connect(lambda evt: state.update(s=evt.state))
    end = time.time() + timeout
    while time.time() < end:
        if state["s"] == CorsairSessionState.CSS_Connected:
            return sdk
        time.sleep(0.25)
    return None


def main():
    ap = argparse.ArgumentParser(description="Christmas lighting for every Corsair iCUE device")
    ap.add_argument("--seconds", type=float, default=0)
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--only", default="", help="comma list of device types, for example keyboard,memorymodule")
    ap.add_argument("--brightness", type=float, default=1.0)
    args = ap.parse_args()

    sdk = connect()
    if not sdk:
        print("Could not reach iCUE. Start iCUE and turn on Settings > Enable SDK.")
        return 1

    wanted = {w.strip().lower() for w in args.only.split(",") if w.strip()}

    if args.list:
        for info in list_devices(sdk):
            leds, mode = build_layout(sdk.get_led_positions(info.device_id)[0] or [], type_name(info))
            print(f"{info.model:32} {type_name(info):18} leds={info.led_count:4} effect={mode if leds else 'none'}", flush=True)
        os._exit(0)

    effects = {}
    stop = {"on": False}
    signal.signal(signal.SIGINT, lambda *a: stop.update(on=True))
    start = last = time.time()
    next_scan = 0.0
    write_errors = 0

    while not stop["on"]:
        now = time.time()
        t, dt = now - start, now - last
        last = now
        if args.seconds and t > args.seconds:
            break

        if now >= next_scan:
            next_scan = now + RESCAN_SECONDS
            try:
                current = {d.device_id: d for d in list_devices(sdk)}
            except Exception:
                current = {}
            for dev_id in [k for k in effects if k not in current]:
                effects.pop(dev_id, None)
            for dev_id, info in current.items():
                if dev_id in effects or (wanted and type_name(info).lower() not in wanted):
                    continue
                try:
                    fx = make_effect(sdk, info, max(0.05, min(1.0, args.brightness)))
                    if fx:
                        sdk.request_control(dev_id, CorsairAccessLevel.CAL_ExclusiveLightingControl)
                        effects[dev_id] = fx
                        print(f"lighting {info.model} ({type_name(info)}, {len(fx.leds)} LEDs, {fx.mode})", flush=True)
                except Exception:
                    continue

        for dev_id, fx in list(effects.items()):
            try:
                if sdk.set_led_colors(dev_id, fx.frame(t, now, dt)) != CorsairError.CE_Success:
                    write_errors += 1
            except Exception:
                write_errors += 1

        time.sleep(max(0, 1 / FPS - (time.time() - now)))

    for dev_id in effects:
        try:
            sdk.release_control(dev_id)
        except Exception:
            pass
    print(f"done ({round(time.time() - start, 1)}s, devices: {len(effects)}, LED write errors: {write_errors})", flush=True)
    os._exit(0)


if __name__ == "__main__":
    sys.exit(main())
