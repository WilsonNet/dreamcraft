#!/usr/bin/env python3
"""Live mouse & camera validation tool for DreamCraft (probe + real macOS OS events)."""

import argparse
import hashlib
import json
import math
import os
import subprocess
import sys
import tempfile
import time
import urllib.request


def get_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=2.0) as resp:
        return json.loads(resp.read().decode("utf-8"))


def get_bytes(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=2.0) as resp:
        return resp.read()


def post_json(url: str, payload: dict) -> dict:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=2.0) as resp:
        return json.loads(resp.read().decode("utf-8"))


def wait_ready(base: str, timeout_s: float = 10.0) -> dict:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        try:
            snap = get_json(f"{base}/camera")
            if snap.get("ok") and snap["screen"][0] > 0:
                return snap
        except Exception:
            time.sleep(0.1)
    raise RuntimeError(f"Control server at {base} did not become ready")


def iso_basis():
    # Matches camera_offset() = normalize({1, 0.816, 1}) * 40
    ox, oy, oz = 1.0, 0.816, 1.0
    olen = math.sqrt(ox * ox + oy * oy + oz * oz)
    pitch_sin = oy / olen
    fx, fz = -ox / olen, -oz / olen
    flen = math.sqrt(fx * fx + fz * fz)
    fx, fz = fx / flen, fz / flen
    # cross(forward, {0,1,0}) = (-fz, 0, fx)
    rx, rz = -fz, fx
    return (fx, fz), (rx, rz), pitch_sin


def dot2(a, b):
    return a[0] * b[0] + a[1] * b[1]


def check_probe(base: str):
    forward, right, pitch_sin = iso_basis()
    snap = post_json(f"{base}/mouse", {"action": "reset_camera"})
    assert snap["follow"] is True, snap

    # 1. Arming: border pixel before arming must NOT scroll; center arms.
    s0 = post_json(f"{base}/mouse", {"action": "set", "x": 0, "y": 360, "focused": True, "on_screen": True, "steps": 5})
    assert not s0["edge_armed"] and s0["follow"] is True, s0
    s1 = post_json(f"{base}/mouse", {"action": "set", "x": 640, "y": 360, "focused": True, "on_screen": True, "steps": 2})
    assert s1["edge_armed"] and s1["follow"] is True, s1

    w, h = s1["screen"]
    # Move to map center via minimap so map bounds (-43..+43) don't clamp 20-frame pans.
    mx, my = minimap_point(s1)
    post_json(f"{base}/mouse", {"action": "set", "x": mx, "y": my, "focused": True, "on_screen": True, "left": True, "steps": 1})
    s_mid = post_json(f"{base}/mouse", {"action": "set", "x": 640, "y": 360, "focused": True, "on_screen": True, "left": False, "steps": 2})

    # 2. Exact border pixels: left (0), right (w), top (0), bottom (h)
    base_t = (s_mid["target"][0], s_mid["target"][2])
    s_left = post_json(f"{base}/mouse", {"action": "set", "x": 0, "y": h * 0.5, "focused": True, "on_screen": True, "steps": 20})
    dx = (s_left["target"][0] - base_t[0], s_left["target"][2] - base_t[1])
    assert s_left["follow"] is False, s_left
    assert dot2(dx, right) < -3.0, f"left edge failed to pan left: {dx} {s_left}"
    assert abs(dot2(dx, forward)) < 0.05, f"left edge drifted vertically: {dx}"

    s_right = post_json(f"{base}/mouse", {"action": "set", "x": w, "y": h * 0.5, "focused": True, "on_screen": True, "steps": 40})
    dx_r = (s_right["target"][0] - s_left["target"][0], s_right["target"][2] - s_left["target"][2])
    assert dot2(dx_r, right) > 5.0, f"right edge failed to pan right: {dx_r} {s_right}"

    mx, my = minimap_point(s_right)
    post_json(f"{base}/mouse", {"action": "set", "x": mx, "y": my, "focused": True, "on_screen": True, "left": True, "steps": 1})
    s_center = post_json(f"{base}/mouse", {"action": "set", "x": 640, "y": 360, "focused": True, "on_screen": True, "left": False, "steps": 2})
    s_top = post_json(f"{base}/mouse", {"action": "set", "x": w * 0.5, "y": 0, "focused": True, "on_screen": True, "steps": 20})
    dy_top = (s_top["target"][0] - s_center["target"][0], s_top["target"][2] - s_center["target"][2])
    assert dot2(dy_top, forward) > 6.0, f"top edge failed to pan up: {dy_top} {s_top}"
    # Verify vertical screen speed equals horizontal screen speed (pitch-compensated)
    horiz_screen_dist = abs(dot2(dx, right))
    vert_screen_dist = abs(dot2(dy_top, forward)) * pitch_sin
    assert abs(horiz_screen_dist - vert_screen_dist) < 0.05, (horiz_screen_dist, vert_screen_dist)

    s_bot = post_json(f"{base}/mouse", {"action": "set", "x": w * 0.5, "y": h, "focused": True, "on_screen": True, "steps": 40})
    dy_bot = (s_bot["target"][0] - s_top["target"][0], s_bot["target"][2] - s_top["target"][2])
    assert dot2(dy_bot, forward) < -10.0, f"bottom edge failed to pan down: {dy_bot} {s_bot}"

    # 3. Unfocus disarms and stops scroll.
    s_unfocus = post_json(f"{base}/mouse", {"action": "set", "x": 0, "y": 0, "focused": False, "on_screen": True, "steps": 2})
    assert not s_unfocus["edge_armed"] and s_unfocus["edge_dir"] == [0, 0], s_unfocus

    # 4. Middle-mouse Camera Grip (1:1 ground locking)
    post_json(f"{base}/mouse", {"action": "reset_camera"})
    g0 = post_json(f"{base}/mouse", {"action": "set", "x": 500, "y": 300, "focused": True, "on_screen": True, "middle": True, "steps": 1})
    assert g0["grip_active"], g0
    g1 = post_json(f"{base}/mouse", {"action": "set", "x": 620, "y": 360, "focused": True, "on_screen": True, "middle": True, "steps": 1})
    assert g1["grip_moved"] and not g1["follow"], g1
    g_delta = (g1["target"][0] - g0["target"][0], g1["target"][2] - g0["target"][2])
    px_to_ortho = g1["fovy"] / h
    expected_right = -120.0 * px_to_ortho
    expected_fwd = (60.0 * px_to_ortho) / pitch_sin
    assert abs(dot2(g_delta, right) - expected_right) < 0.05, (dot2(g_delta, right), expected_right)
    assert abs(dot2(g_delta, forward) - expected_fwd) < 0.05, (dot2(g_delta, forward), expected_fwd)
    g2 = post_json(f"{base}/mouse", {"action": "set", "x": 620, "y": 360, "focused": True, "on_screen": True, "middle": False, "steps": 2})
    assert not g2["grip_active"] and g2["vel"] == [0, 0, 0], g2

    # 5. Space + Left Drag Camera Grip (trackpad fallback)
    post_json(f"{base}/mouse", {"action": "reset_camera"})
    sp0 = post_json(f"{base}/mouse", {"action": "set", "x": 500, "y": 300, "focused": True, "on_screen": True, "left": True, "space": True, "steps": 1})
    assert sp0["grip_active"], sp0
    sp1 = post_json(f"{base}/mouse", {"action": "set", "x": 400, "y": 250, "focused": True, "on_screen": True, "left": True, "space": True, "steps": 1})
    assert sp1["grip_moved"] and not sp1["follow"], sp1
    sp_delta = (sp1["target"][0] - sp0["target"][0], sp1["target"][2] - sp0["target"][2])
    assert dot2(sp_delta, right) > 1.0 and dot2(sp_delta, forward) < -1.0, sp_delta
    sp2 = post_json(f"{base}/mouse", {"action": "set", "x": 400, "y": 250, "focused": True, "on_screen": True, "left": False, "space": False, "steps": 1})
    assert not sp2["grip_active"], sp2

    # 6. Wheel Zoom
    z0 = sp2["zoom"]
    z1 = post_json(f"{base}/mouse", {"action": "set", "x": 640, "y": 360, "focused": True, "on_screen": True, "wheel": 2.0, "steps": 15})
    assert z1["target_zoom"] < z0 and z1["zoom"] < z0, (z0, z1)

    # 7. Minimap click & drag
    post_json(f"{base}/mouse", {"action": "reset_camera"})
    mx, my = minimap_point(s1, 0.8, 0.5)
    m0 = post_json(f"{base}/mouse", {"action": "set", "x": mx, "y": my, "focused": True, "on_screen": True, "left": True, "steps": 1})
    assert m0["minimap_dragging"] and not m0["follow"] and m0["target"][0] > 10.0, m0
    mx, my = minimap_point(m0, 0.2, 0.5)
    m1 = post_json(f"{base}/mouse", {"action": "set", "x": mx, "y": my, "focused": True, "on_screen": True, "left": True, "steps": 1})
    assert m1["target"][0] < m0["target"][0] - 10.0, (m0["target"], m1["target"])

    # 8. Clear probe and check screenshot works
    post_json(f"{base}/mouse", {"action": "clear"})
    shot = get_bytes(f"{base}/screenshot")
    assert shot.startswith(b"\x89PNG"), "screenshot failed"
    print("PROBE VALIDATION PASSED: edge pan, pitch equalization, MMB grip, Space+drag, wheel zoom, minimap drag, screenshot OK")


_SWIFT_BIN = None


def ensure_swift_driver() -> str:
    global _SWIFT_BIN
    if _SWIFT_BIN and os.path.exists(_SWIFT_BIN):
        return _SWIFT_BIN
    swift_code = r'''
import AppKit
import CoreGraphics
import Foundation

let args = CommandLine.arguments
if args.count < 2 { exit(2) }
let cmd = args[1]

let src = CGEventSource(stateID: .hidSystemState)
src?.localEventsSuppressionInterval = 0.0

func postMove(_ x: Double, _ y: Double, button: CGMouseButton = .left, type: CGEventType = .mouseMoved) {
    let pt = CGPoint(x: x, y: y)
    let ev = CGEvent(mouseEventSource: src, mouseType: type, mouseCursorPosition: pt, mouseButton: button)
    ev?.post(tap: .cghidEventTap)
}

func warp(_ x: Double, _ y: Double) {
    postMove(x, y, type: .mouseMoved)
    usleep(12000)
}

switch cmd {
case "status":
    print("ax=\(AXIsProcessTrusted())")
case "activate":
    let pid = Int32(args[2])!
    if let app = NSRunningApplication(processIdentifier: pid) {
        app.activate()
    }
case "move":
    let x = Double(args[2])!, y = Double(args[3])!
    warp(x, y)
    postMove(x, y, type: .mouseMoved)
case "sweep":
    let x0 = Double(args[2])!, y0 = Double(args[3])!
    let x1 = Double(args[4])!, y1 = Double(args[5])!
    for i in 0...12 {
        let t = Double(i) / 12.0
        let x = x0 + (x1 - x0) * t
        let y = y0 + (y1 - y0) * t
        warp(x, y)
        postMove(x, y, type: .mouseMoved)
        usleep(12000)
    }
case "click_left":
    let x = Double(args[2])!, y = Double(args[3])!
    warp(x, y)
    postMove(x, y, type: .mouseMoved)
    usleep(30000)
    postMove(x, y, button: .left, type: .leftMouseDown)
    usleep(40000)
    postMove(x, y, button: .left, type: .leftMouseUp)
case "mmb_drag":
    let x0 = Double(args[2])!, y0 = Double(args[3])!
    let x1 = Double(args[4])!, y1 = Double(args[5])!
    warp(x0, y0)
    postMove(x0, y0, type: .mouseMoved)
    usleep(20000)
    postMove(x0, y0, button: .center, type: .otherMouseDown)
    for i in 1...10 {
        let t = Double(i) / 10.0
        let x = x0 + (x1 - x0) * t
        let y = y0 + (y1 - y0) * t
        usleep(16000)
        warp(x, y)
        postMove(x, y, button: .center, type: .otherMouseDragged)
    }
    usleep(20000)
    postMove(x1, y1, button: .center, type: .otherMouseUp)
case "wheel":
    let dy = Int32(args[2])!
    if let ev = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: dy, wheel2: 0, wheel3: 0) {
        ev.post(tap: .cghidEventTap)
    }
default:
    exit(2)
}
'''
    digest = hashlib.sha1(swift_code.encode("utf-8")).hexdigest()[:10]
    bin_path = f"/tmp/dreamcraft_mouse_driver_{digest}"
    if os.path.exists(bin_path):
        _SWIFT_BIN = bin_path
        return bin_path
    with tempfile.NamedTemporaryFile("w", suffix=".swift", delete=False) as f:
        f.write(swift_code)
        src_path = f.name
    try:
        subprocess.check_call(
            ["swiftc", "-module-cache-path", "/tmp/swift_cache", src_path, "-o", bin_path]
        )
    finally:
        os.unlink(src_path)
    _SWIFT_BIN = bin_path
    return bin_path


def run_swift_mouse(args: list[str]) -> str:
    bin_path = ensure_swift_driver()
    return subprocess.check_output([bin_path] + args, text=True).strip()


def minimap_point(snap: dict, fx: float = 0.5, fy: float = 0.5) -> tuple[float, float]:
    """Point inside the live HUD minimap (the HUD layout owns its position)."""
    x, y, mw, mh = snap["minimap"]
    return x + mw * fx, y + mh * fy


def check_os(base: str, pid: int | None):
    post_json(f"{base}/mouse", {"action": "reset_camera"})
    if pid is not None:
        run_swift_mouse(["activate", str(pid)])
        time.sleep(0.25)

    snap = get_json(f"{base}/camera")
    wx, wy = snap["window_pos"]
    w, h = snap["screen"]
    print("initial os:", {"window_pos": [wx, wy], "screen": [w, h], "focused": snap["window_focused"], "on_screen": snap["cursor_on_screen"]})

    # Focus window and center camera via minimap click -> move to center to arm edge pan.
    run_swift_mouse(["click_left", str(wx + w * 0.5), str(wy + h * 0.5)])
    time.sleep(0.1)
    mx, my = minimap_point(snap)
    run_swift_mouse(["click_left", str(wx + mx), str(wy + my)])
    time.sleep(0.1)
    run_swift_mouse(["move", str(wx + w * 0.5), str(wy + h * 0.5)])
    time.sleep(0.15)
    c_mid = get_json(f"{base}/camera")
    print("os center armed:", {k: c_mid[k] for k in ("window_focused", "cursor_on_screen", "cursor_inside", "edge_armed", "target")})
    assert c_mid["window_focused"] and c_mid["cursor_inside"] and c_mid["edge_armed"], c_mid
    assert abs(c_mid["target"][0]) < 2.0 and abs(c_mid["target"][2]) < 2.0, c_mid["target"]

    # Real OS edge scroll: right (x = w - 6), left (x = 4), top (y = 6), bottom (y = h - 6)
    run_swift_mouse(["move", str(wx + w - 6), str(wy + h * 0.5)])
    time.sleep(0.25)
    c_right = get_json(f"{base}/camera")
    print("os right edge:", {k: c_right[k] for k in ("cursor_on_screen", "cursor_inside", "edge_dir", "mouse", "follow", "target")})
    assert c_right["target"][0] > c_mid["target"][0] + 1.0, (c_mid["target"], c_right["target"])

    run_swift_mouse(["move", str(wx + 4), str(wy + h * 0.5)])
    time.sleep(0.35)
    c_left = get_json(f"{base}/camera")
    print("os left edge:", {k: c_left[k] for k in ("cursor_inside", "edge_dir", "mouse", "target")})
    assert c_left["target"][0] < c_right["target"][0] - 1.0, (c_right["target"], c_left["target"])

    run_swift_mouse(["move", str(wx + w * 0.5), str(wy + 6)])
    time.sleep(0.25)
    c_top = get_json(f"{base}/camera")
    print("os top edge:", {k: c_top[k] for k in ("cursor_inside", "edge_dir", "mouse", "target")})
    assert c_top["target"][2] < c_left["target"][2] - 1.0, (c_left["target"], c_top["target"])

    run_swift_mouse(["move", str(wx + w * 0.5), str(wy + h - 6)])
    time.sleep(0.35)
    c_bot = get_json(f"{base}/camera")
    print("os bottom edge:", {k: c_bot[k] for k in ("cursor_inside", "edge_dir", "mouse", "target")})
    assert c_bot["target"][2] > c_top["target"][2] + 1.0, (c_top["target"], c_bot["target"])

    # Moving outside the window immediately stops edge scrolling (no runaway drift).
    run_swift_mouse(["move", str(wx - 60), str(wy + h * 0.5)])
    time.sleep(0.28)
    c_out = get_json(f"{base}/camera")
    print("os outside window:", {k: c_out[k] for k in ("cursor_inside", "edge_dir", "mouse", "vel")})
    assert not c_out["cursor_inside"] and c_out["edge_dir"] == [0.0, 0.0] and c_out["vel"] == [0.0, 0.0, 0.0], c_out

    # Recenter via minimap, then test real OS MMB drag and wheel zoom
    mx, my = minimap_point(snap)
    run_swift_mouse(["click_left", str(wx + mx), str(wy + my)])
    time.sleep(0.08)
    run_swift_mouse(["move", str(wx + w * 0.5), str(wy + h * 0.5)])
    time.sleep(0.08)
    before_mmb = get_json(f"{base}/camera")
    run_swift_mouse(["mmb_drag", str(wx + w * 0.5), str(wy + h * 0.5), str(wx + w * 0.5 + 120), str(wy + h * 0.5 + 60)])
    time.sleep(0.08)
    after_mmb = get_json(f"{base}/camera")
    delta_mmb = math.hypot(after_mmb["target"][0] - before_mmb["target"][0], after_mmb["target"][2] - before_mmb["target"][2])
    print("os MMB drag:", {"before": before_mmb["target"], "after": after_mmb["target"], "dist": round(delta_mmb, 3)})
    assert delta_mmb > 1.5, (before_mmb["target"], after_mmb["target"])

    z0 = after_mmb["zoom"]
    run_swift_mouse(["wheel", "3"])
    time.sleep(0.25)
    after_wheel = get_json(f"{base}/camera")
    print("os wheel zoom:", {"before": z0, "after": after_wheel["zoom"], "target_zoom": after_wheel["target_zoom"]})
    assert after_wheel["target_zoom"] < z0 and after_wheel["zoom"] < z0, (z0, after_wheel)
    print("OS VALIDATION PASSED: live macOS edge scroll (L/R/T/B), MMB grip, and wheel zoom OK")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=7778)
    parser.add_argument("--mode", choices=["probe", "os", "both"], default="probe")
    parser.add_argument("--launch", action="store_true")
    parser.add_argument("--bin", default="./bin/dreamcraft-dev")
    args = parser.parse_args()

    proc = None
    if args.launch:
        proc = subprocess.Popen([args.bin, f"--control={args.port}"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

    base = f"http://127.0.0.1:{args.port}"
    try:
        wait_ready(base)
        if args.mode in ("probe", "both"):
            check_probe(base)
        if args.mode in ("os", "both"):
            check_os(base, proc.pid if proc else None)
    finally:
        if proc is not None:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()


if __name__ == "__main__":
    main()
