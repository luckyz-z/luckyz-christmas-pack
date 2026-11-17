import argparse, math, os, random, signal, sys, time
from cuesdk import (CueSdk, CorsairSessionState, CorsairDeviceFilter, CorsairDeviceType,
                    CorsairLedColor, CorsairAccessLevel, CorsairError)

FPS = 30
TWINKLE = [(255, 170, 20), (255, 255, 255), (255, 20, 20), (0, 255, 70), (255, 90, 160)]

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))
def add(c, d, k): return tuple(min(255, int(c[i] + d[i] * k)) for i in range(3))

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--seconds", type=float, default=0); args = ap.parse_args()
    state = {"s": None}
    sdk = CueSdk(); sdk.connect(lambda evt: state.update(s=evt.state))
    for _ in range(80):
        time.sleep(0.25)
        if state["s"] == CorsairSessionState.CSS_Connected: break
    else:
        print("iCUE not reachable (is iCUE running with the SDK enabled?)"); return 1

    devs, _ = sdk.get_devices(CorsairDeviceFilter(device_type_mask=CorsairDeviceType.CDT_All))
    kb = next((d for d in devs if d.type == CorsairDeviceType.CDT_Keyboard), None)
    ram = next((d for d in devs if d.type == CorsairDeviceType.CDT_MemoryModule), None)
    targets = [d for d in (kb, ram) if d]
    for d in targets:
        err = sdk.request_control(d.device_id, CorsairAccessLevel.CAL_ExclusiveLightingControl)
        print(f"control {d.model}: {err}")

    kb_leds = []
    if kb:
        pos, _ = sdk.get_led_positions(kb.device_id)
        xs = [p.cx for p in pos]; ys = [p.cy for p in pos]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        kb_leds = [(p.id, (p.cx - x0) / ((x1 - x0) or 1), (p.cy - y0) / ((y1 - y0) or 1)) for p in pos]
    ram_leds = []
    if ram:
        pos, _ = sdk.get_led_positions(ram.device_id)
        ram_leds = [p.id for p in pos]

    flares = {}
    snow = [{"x": random.random(), "y": -random.random(), "v": 0.25 + random.random() * 0.4} for _ in range(7)]
    running = {"on": True}
    signal.signal(signal.SIGINT, lambda *a: running.update(on=False))
    t0 = last = time.time(); errs = 0

    while running["on"]:
        now = time.time(); t = now - t0; dt = now - last; last = now
        if args.seconds and t > args.seconds: break

        if kb:
            for f in snow:
                f["y"] += f["v"] * dt
                if f["y"] > 1.15: f["x"], f["y"], f["v"] = random.random(), -0.1, 0.25 + random.random() * 0.4
            if random.random() < 0.55 and kb_leds:
                flares[random.choice(kb_leds)[0]] = (random.choice(TWINKLE), now)
            out = []
            for lid, x, y in kb_leds:
                s = 0.5 + 0.5 * math.sin(2 * math.pi * (x * 1.6 - t * 0.10))
                c = lerp((70, 0, 4), (0, 55, 14), s)
                fl = flares.get(lid)
                if fl:
                    k = max(0.0, 1.0 - (now - fl[1]) / 1.0)
                    if k <= 0: flares.pop(lid, None)
                    else: c = add(c, fl[0], k)
                for f in snow:
                    d = math.hypot((x - f["x"]) * 1.5, y - f["y"])
                    if d < 0.11: c = add(c, (255, 255, 255), (1 - d / 0.11) * 0.9)
                out.append(CorsairLedColor(lid, c[0], c[1], c[2], 255))
            if sdk.set_led_colors(kb.device_id, out)!= CorsairError.CE_Success: errs += 1

        if ram:
            shift = int(t * 5)
            out = []
            for i, lid in enumerate(ram_leds):
                k = ((i % 10) + shift) % 6
                c = (255, 10, 20) if k < 2 else ((255, 235, 220) if k < 4 else (0, 190, 50))
                if random.random() < 0.015: c = (255, 170, 20)
                out.append(CorsairLedColor(lid, c[0], c[1], c[2], 255))
            if sdk.set_led_colors(ram.device_id, out)!= CorsairError.CE_Success: errs += 1

        time.sleep(max(0, 1 / FPS - (time.time() - now)))

    for d in targets: sdk.release_control(d.device_id)
    print(f"done ({round(time.time() - t0, 1)}s, led write errors: {errs})")
    return 0

if __name__ == "__main__":
    sys.exit(main())


