#!/usr/bin/env python3
"""One-off: assets/maps/level_N.json -> godot/scenes/maps/level_N.tscn

Run once per map. The resulting .tscn is the source of truth thereafter
and is edited in the Godot editor, not regenerated.

SAFETY: once a level_*.tscn has been hand-assembled with gameplay nodes
(Player, Enemy, UILayer, HUD, TouchControls, ...), regenerating it from
JSON would silently destroy that assembly. This script therefore refuses
to overwrite a destination .tscn that contains anything other than a
Platform instance, the PlayerSpawn marker, or scaffolding nodes (the
scene root, the "Platforms" container), unless --force is passed.

Usage: python3 tools/convert_map.py <level_name> [--force]
       python3 tools/convert_map.py level_1
"""
import argparse
import json
import re
import sys
from pathlib import Path

KIND = {"brick": 0, "ground": 1, "stone": 2}
PLATFORM_SCENE_PATH = "res://scenes/platform/platform.tscn"

ROOT = Path(__file__).resolve().parent.parent


def _parse_tscn(text: str):
    """Return (ext_resources: id -> path, nodes: list of dicts)."""
    ext_resources = {}
    for block in re.finditer(r"\[ext_resource\b[^\]]*\]", text):
        s = block.group(0)
        path_m = re.search(r'path="([^"]+)"', s)
        id_m = re.search(r'id="([^"]+)"', s)
        if path_m and id_m:
            ext_resources[id_m.group(1)] = path_m.group(1)

    nodes = []
    for block in re.finditer(r"\[node\b[^\]]*\]", text):
        s = block.group(0)
        name_m = re.search(r'name="([^"]+)"', s)
        type_m = re.search(r'\btype="([^"]+)"', s)
        parent_m = re.search(r'parent="([^"]+)"', s)
        inst_m = re.search(r'instance=ExtResource\("([^"]+)"\)', s)
        nodes.append(
            {
                "name": name_m.group(1) if name_m else None,
                "type": type_m.group(1) if type_m else None,
                "parent": parent_m.group(1) if parent_m else None,
                "instance_id": inst_m.group(1) if inst_m else None,
            }
        )
    return ext_resources, nodes


def _find_unexpected_nodes(text: str):
    """Return the list of node dicts that are not Platform instances,
    PlayerSpawn, or known scaffolding (scene root / "Platforms" container).
    """
    ext_resources, nodes = _parse_tscn(text)
    unexpected = []
    for n in nodes:
        if n["parent"] is None:
            # Scene root node -- always allowed.
            continue
        if n["name"] == "Platforms" and n["type"] == "Node2D":
            continue
        if n["name"] == "PlayerSpawn" and n["type"] == "Marker2D":
            continue
        if n["instance_id"] is not None and ext_resources.get(n["instance_id"]) == PLATFORM_SCENE_PATH:
            continue
        unexpected.append(n)
    return unexpected


def convert(name: str, force: bool = False) -> None:
    src = ROOT / "assets" / "maps" / f"{name}.json"
    dst = ROOT / "godot" / "scenes" / "maps" / f"{name}.tscn"
    dst.parent.mkdir(parents=True, exist_ok=True)

    if dst.exists():
        existing_text = dst.read_text()
        unexpected = _find_unexpected_nodes(existing_text)
        if unexpected:
            print(f"Found {len(unexpected)} non-Platform/PlayerSpawn node(s) in {dst}:")
            for n in unexpected:
                print(
                    f"  - name={n['name']!r} type={n['type']!r} "
                    f"parent={n['parent']!r} instance_id={n['instance_id']!r}"
                )
            if not force:
                print(
                    f"Refusing to overwrite {dst}: it has already been hand-assembled "
                    "with gameplay nodes and regenerating it would destroy them.\n"
                    "Pass --force to overwrite anyway."
                )
                raise SystemExit(1)
            print(f"--force given: overwriting {dst} anyway, destroying the nodes above.")
        else:
            print(f"{dst} exists but contains only Platform/PlayerSpawn/scaffolding nodes; proceeding.")

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


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert assets/maps/<name>.json to godot/scenes/maps/<name>.tscn"
    )
    parser.add_argument(
        "name",
        help="Map name, e.g. level_1. Required -- there is no default, "
        "to avoid accidentally clobbering level_1.tscn.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite the destination even if it contains non-Platform/PlayerSpawn nodes.",
    )
    args = parser.parse_args()
    convert(args.name, args.force)


if __name__ == "__main__":
    main()
