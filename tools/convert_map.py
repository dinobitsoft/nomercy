#!/usr/bin/env python3
"""One-off: assets/maps/level_N.json -> godot/scenes/maps/level_N.tscn

Run once per map. The resulting .tscn is the source of truth thereafter
and is edited in the Godot editor, not regenerated.

Usage: python3 tools/convert_map.py level_1
"""
import json
import sys
from pathlib import Path

KIND = {"brick": 0, "ground": 1, "stone": 2}

ROOT = Path(__file__).resolve().parent.parent


def convert(name: str) -> None:
    src = ROOT / "assets" / "maps" / f"{name}.json"
    dst = ROOT / "godot" / "scenes" / "maps" / f"{name}.tscn"
    dst.parent.mkdir(parents=True, exist_ok=True)

    data = json.loads(src.read_text())
    platforms = data["platforms"]
    spawn = data["playerSpawn"]

    lines = [
        f"[gd_scene load_steps=2 format=3]",
        "",
        '[ext_resource type="PackedScene" '
        'path="res://scenes/platform/platform.tscn" id="1"]',
        "",
        f'[node name="{name}" type="Node2D"]',
        "",
        '[node name="Platforms" type="Node2D" parent="."]',
        "",
    ]

    for i, p in enumerate(platforms):
        kind = KIND.get(p["type"])
        if kind is None:
            raise SystemExit(f"Unknown platform type {p['type']!r} at index {i}")
        lines += [
            f'[node name="Platform{i}" parent="Platforms" '
            f'instance=ExtResource("1")]',
            f'position = Vector2({p["x"]}, {p["y"]})',
            f"kind = {kind}",
            f'size = Vector2({p["width"]}, {p["height"]})',
            "",
        ]

    lines += [
        '[node name="PlayerSpawn" type="Marker2D" parent="."]',
        f'position = Vector2({spawn["x"]}, {spawn["y"]})',
        "",
    ]

    dst.write_text("\n".join(lines))
    print(f"Wrote {dst} ({len(platforms)} platforms)")


if __name__ == "__main__":
    convert(sys.argv[1] if len(sys.argv) > 1 else "level_1")
