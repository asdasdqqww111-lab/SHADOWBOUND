#!/usr/bin/env python3
"""
SHADOWBOUND — Phase 3 Automated Project Validation Suite.

Validates:
1. Repository structure & security hygiene (zero secrets/keystores/APKs).
2. `project.godot` syntax, version, main scene, autoloads, inputs, physics layers, RTL & Android settings.
3. GDScript AST parsing via gdtoolkit (not the native Godot compiler) (`gdparse`) and style/linting (`gdlint`) across all `.gd` scripts.
4. Autoload vs `class_name` collision checks and strict Variant typing checks.
5. Deep `.tscn` and `.tres` validation: format=3, exact `load_steps`, ExtResource file existence,
   SubResource reference integrity, node hierarchy resolution, script `@onready $NodePath` verification,
   AtlasTexture bounds inside actual PNG dimensions, and all 23 Stickman animation definitions.
6. JSON config & bilingual English/Arabic RTL string parity and Unicode validation.
7. Asset integrity (PNG RGBA dimensions, Cairo TrueType font header, SVG icon XML, licenses & credits).
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from PIL import Image, ImageFont

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_DIRS = [
    "scenes",
    "scripts",
    "assets",
    "resources",
    "data",
    "addons",
    "tests",
    "licenses",
    "docs",
]

REQUIRED_INPUT_ACTIONS = [
    "move_left",
    "move_right",
    "move_up",
    "move_down",
    "jump",
    "dodge",
    "attack",
    "block",
    "sprint",
    "interact",
    "switch_mode",
    "pause",
]

REQUIRED_ANIMATIONS = [
    "idle",
    "run",
    "jump",
    "fall",
    "dodge",
    "attack",
    "block",
    "wall_slide",
    "td_idle_down",
    "td_idle_up",
    "td_idle_side",
    "td_walk_down",
    "td_walk_up",
    "td_walk_side",
    "td_dodge",
    "td_attack",
    "td_block",
    "attack_2",
    "attack_3",
    "hurt",
    "td_attack_2",
    "td_attack_3",
    "td_hurt",
]

FORBIDDEN_SECRET_PATTERNS = (".keystore", ".jks", ".pem", ".key", ".p12", ".apk", ".aab")

passed = 0
failed = 0
failures: list[str] = []


def check(condition: bool, message: str) -> None:
    global passed, failed
    if condition:
        passed += 1
        print(f"[PASS] {message}")
    else:
        failed += 1
        failures.append(message)
        print(f"[FAIL] {message}")


def res_to_path(res_path: str) -> Path:
    assert res_path.startswith("res://"), f"Expected res:// path, got {res_path}"
    return ROOT / res_path[len("res://"):]


def find_tool(name: str) -> str | None:
    found = shutil.which(name)
    if found:
        return found
    candidate = Path.home() / ".local" / "bin" / name
    if candidate.exists():
        return str(candidate)
    return None


def validate_structure_and_security() -> None:
    print("\n--- 1. Directory Structure & Security Hygiene ---")
    for d in REQUIRED_DIRS:
        check((ROOT / d).is_dir(), f"Required directory exists: {d}/")

    check((ROOT / "README.md").is_file(), "README.md exists")
    check((ROOT / "ASSET_CREDITS.md").is_file(), "ASSET_CREDITS.md exists")
    check((ROOT / "export_presets.cfg.example").is_file(), "export_presets.cfg.example template exists")
    check(not (ROOT / "export_presets.cfg").exists(), "No local export_presets.cfg with credentials committed")

    leaked = []
    for p in ROOT.rglob("*"):
        if ".git" in p.parts:
            continue
        if p.is_file() and p.suffix.lower() in FORBIDDEN_SECRET_PATTERNS:
            leaked.append(str(p.relative_to(ROOT)))
    check(len(leaked) == 0, f"Zero keystores, private keys, or unverified APKs in repo (found: {leaked})")


def validate_project_godot() -> set[str]:
    print("\n--- 2. project.godot Configuration ---")
    proj_file = ROOT / "project.godot"
    check(proj_file.is_file(), "project.godot exists")
    text = proj_file.read_text(encoding="utf-8")

    check("config_version=5" in text, "project.godot uses Godot 4 config_version=5")
    check('config/name="SHADOWBOUND"' in text, "Project name is SHADOWBOUND")
    check('renderer/rendering_method="gl_compatibility"' in text, "GL Compatibility renderer set for Android 9+")
    check('renderer/rendering_method.mobile="gl_compatibility"' in text, "Mobile GL Compatibility renderer set")
    check("locale/include_text_server_data=true" in text, "Arabic RTL TextServer data enabled for export")
    check("pointing/emulate_touch_from_mouse=true" in text, "Touch emulation configured for testing")
    check('window/stretch/mode="canvas_items"' in text, "Responsive canvas_items stretch mode configured")
    check('window/stretch/aspect="expand"' in text, "Responsive expand aspect configured for wide Android screens")

    m_main = re.search(r'run/main_scene="([^"]+)"', text)
    check(m_main is not None and res_to_path(m_main.group(1)).is_file(), "Main scene configured and exists on disk")

    m_icon = re.search(r'config/icon="([^"]+)"', text)
    check(m_icon is not None and res_to_path(m_icon.group(1)).is_file(), "Application icon configured and exists")

    autoload_names: set[str] = set()
    in_autoload = False
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("[") and s.endswith("]"):
            in_autoload = s == "[autoload]"
            continue
        if in_autoload and "=" in s:
            name, val = s.split("=", 1)
            name = name.strip()
            path_str = val.strip().strip('"').lstrip("*")
            autoload_names.add(name)
            check(res_to_path(path_str).is_file(), f"Autoload '{name}' script exists: {path_str}")

    for action in REQUIRED_INPUT_ACTIONS:
        check(re.search(rf"^{re.escape(action)}=\{{", text, re.MULTILINE) is not None, f"Input action defined: {action}")

    return autoload_names


def validate_gdscripts(autoload_names: set[str]) -> None:
    print("\n--- 3. GDScript Parsing, Linting & Static Safety ---")
    gd_files = sorted(ROOT.rglob("*.gd"))
    check(len(gd_files) >= 10, f"Found {len(gd_files)} GDScript files")

    gdparse_bin = find_tool("gdparse")
    gdlint_bin = find_tool("gdlint")
    check(gdparse_bin is not None, "gdparse (Godot 4 GDScript AST parser) available")
    check(gdlint_bin is not None, "gdlint (Godot 4 GDScript linter) available")

    if gdparse_bin:
        for gd in gd_files:
            rel = gd.relative_to(ROOT)
            proc = subprocess.run([gdparse_bin, str(gd)], capture_output=True, text=True)
            check(proc.returncode == 0, f"gdparse AST valid: {rel}" + (f" -> {proc.stderr.strip()}" if proc.returncode != 0 else ""))

    if gdlint_bin:
        proc = subprocess.run([gdlint_bin] + [str(g) for g in gd_files], capture_output=True, text=True, cwd=ROOT)
        out_msg = (proc.stdout + proc.stderr).strip()
        check(proc.returncode == 0, f"gdlint clean across all {len(gd_files)} scripts" + (f"\n{out_msg}" if proc.returncode != 0 else ""))

    # Verify zero autoload vs class_name collisions & zero unsafe JSON := inference
    all_signals: set[str] = {"pressed", "area_entered", "body_entered", "body_exited"}
    all_funcs: set[str] = set()
    script_funcs: dict[Path, set[str]] = {}
    for gd in gd_files:
        src = gd.read_text(encoding="utf-8")
        all_signals |= set(re.findall(r"^signal\s+(\w+)", src, re.MULTILINE))
        fns = set(re.findall(r"^(?:static\s+)?func\s+(\w+)", src, re.MULTILINE))
        script_funcs[gd] = fns
        all_funcs |= fns

    for gd in gd_files:
        rel = gd.relative_to(ROOT)
        src = gd.read_text(encoding="utf-8")
        m_cls = re.search(r"^class_name\s+(\w+)", src, re.MULTILINE)
        if m_cls:
            cname = m_cls.group(1)
            check(cname not in autoload_names, f"class_name '{cname}' in {rel} does not shadow any Autoload")
        check(":= JSON.parse_string" not in src, f"No unsafe Variant ':=' on JSON.parse_string in {rel}")

    # Cross-script signal & dynamic method reference verification
    sig_errors: list[str] = []
    for gd in gd_files:
        rel = gd.relative_to(ROOT)
        src = gd.read_text(encoding="utf-8")
        local_fns = script_funcs[gd]
        for m in re.finditer(r"\.connect\(\s*([_a-zA-Z]\w*)\s*\)", src):
            if m.group(1) not in local_fns:
                sig_errors.append(f"{rel}:missing_cb:{m.group(1)}")
        for m in re.finditer(r'\.connect\(\s*"(\w+)"\s*,\s*([_a-zA-Z]\w*)\s*\)', src):
            if m.group(1) not in all_signals:
                sig_errors.append(f"{rel}:unknown_sig:{m.group(1)}")
            if m.group(2) not in local_fns:
                sig_errors.append(f"{rel}:missing_cb:{m.group(2)}")
        for m in re.finditer(r"\.(\w+)\.connect\(", src):
            if m.group(1) not in all_signals:
                sig_errors.append(f"{rel}:unknown_sig:{m.group(1)}")
        for m in re.finditer(r'\.(?:call|has_method)\(\s*"(\w+)"', src):
            if m.group(1) not in all_funcs:
                sig_errors.append(f"{rel}:unknown_fn:{m.group(1)}")
        for m in re.finditer(r'has_signal\(\s*"(\w+)"\)', src):
            if m.group(1) not in all_signals:
                sig_errors.append(f"{rel}:unknown_sig:{m.group(1)}")
    check(
        len(sig_errors) == 0,
        f"Cross-script audit clean ({len(all_signals)} signals, {len(all_funcs)} functions; errors: {sig_errors})",
    )


def parse_godot_text_resource(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    header_m = re.match(r"\[(gd_scene|gd_resource)\s+([^\]]+)\]", text)
    if not header_m:
        return {"valid_header": False}

    header_kind = header_m.group(1)
    header_attrs = header_m.group(2)
    fmt_m = re.search(r"format=(\d+)", header_attrs)
    steps_m = re.search(r"load_steps=(\d+)", header_attrs)

    ext_resources: dict[str, tuple[str, str]] = {}
    for m in re.finditer(r'^\[ext_resource\s+([^\]]+)\]', text, re.MULTILINE):
        attrs = m.group(1)
        t_m = re.search(r'type="([^"]+)"', attrs)
        p_m = re.search(r'path="([^"]+)"', attrs)
        i_m = re.search(r'id="([^"]+)"', attrs)
        if t_m and p_m and i_m:
            ext_resources[i_m.group(1)] = (t_m.group(1), p_m.group(1))

    sub_resources: dict[str, tuple[str, str]] = {}
    sub_headers = list(re.finditer(r'^\[sub_resource\s+([^\]]+)\]', text, re.MULTILINE))
    for idx, m in enumerate(sub_headers):
        attrs = m.group(1)
        t_m = re.search(r'type="([^"]+)"', attrs)
        i_m = re.search(r'id="([^"]+)"', attrs)
        start = m.end()
        next_sec = re.search(r"^\[(sub_resource|node|resource|connection)", text[start:], re.MULTILINE)
        body = text[start:start + next_sec.start()] if next_sec else text[start:]
        if t_m and i_m:
            sub_resources[i_m.group(1)] = (t_m.group(1), body)

    # Parse nodes and reconstruct full scene tree paths
    nodes: dict[str, dict] = {}
    root_name: str | None = None
    node_headers = list(re.finditer(r'^\[node\s+([^\]]+)\]', text, re.MULTILINE))
    for m in node_headers:
        attrs = m.group(1)
        n_m = re.search(r'name="([^"]+)"', attrs)
        p_m = re.search(r'parent="([^"]+)"', attrs)
        inst_m = re.search(r'instance=ExtResource\("([^"]+)"\)', attrs)
        start = m.end()
        next_sec = re.search(r"^\[(node|connection|editable)", text[start:], re.MULTILINE)
        body = text[start:start + next_sec.start()] if next_sec else text[start:]
        scr_m = re.search(r'^script\s*=\s*ExtResource\("([^"]+)"\)', body, re.MULTILINE)
        if not n_m:
            continue
        name = n_m.group(1)
        parent = p_m.group(1) if p_m else None
        if parent is None:
            root_name = name
            rel_path = "."
        elif parent == ".":
            rel_path = name
        else:
            rel_path = f"{parent}/{name}"
        nodes[rel_path] = {
            "name": name,
            "parent": parent,
            "instance_ext": inst_m.group(1) if inst_m else None,
            "script_ext": scr_m.group(1) if scr_m else None,
        }

    ext_refs = set(re.findall(r'ExtResource\("([^"]+)"\)', text))
    sub_refs = set(re.findall(r'SubResource\("([^"]+)"\)', text))

    return {
        "valid_header": True,
        "kind": header_kind,
        "format": int(fmt_m.group(1)) if fmt_m else -1,
        "load_steps": int(steps_m.group(1)) if steps_m else None,
        "ext": ext_resources,
        "sub": sub_resources,
        "nodes": nodes,
        "root_name": root_name,
        "ext_refs": ext_refs,
        "sub_refs": sub_refs,
        "raw": text,
    }


def validate_scenes_and_resources() -> None:
    print("\n--- 4. Scene (.tscn) & Resource (.tres) Integrity ---")
    all_res_files = sorted(list(ROOT.rglob("*.tscn")) + list(ROOT.rglob("*.tres")))
    check(len(all_res_files) >= 9, f"Found {len(all_res_files)} Godot scenes and resources")

    for rf in all_res_files:
        rel = rf.relative_to(ROOT)
        info = parse_godot_text_resource(rf)
        check(info["valid_header"] and info["format"] == 3, f"{rel}: valid Godot 4 format=3 header")
        if not info["valid_header"]:
            continue

        expected_steps = 1 + len(info["ext"]) + len(info["sub"])
        if info["load_steps"] is not None:
            check(
                info["load_steps"] == expected_steps,
                f"{rel}: load_steps={info['load_steps']} matches exact count ({expected_steps})",
            )

        # Verify every ExtResource target exists on disk
        missing_files = []
        for eid, (_etype, epath) in info["ext"].items():
            if not res_to_path(epath).is_file():
                missing_files.append(f"{eid}:{epath}")
        check(len(missing_files) == 0, f"{rel}: all {len(info['ext'])} ExtResource files exist on disk")

        # Verify all referenced ExtResource & SubResource IDs exist
        bad_ext = sorted(info["ext_refs"] - set(info["ext"].keys()))
        bad_sub = sorted(info["sub_refs"] - set(info["sub"].keys()))
        check(len(bad_ext) == 0 and len(bad_sub) == 0, f"{rel}: zero dangling ExtResource/SubResource refs")

        # Verify AtlasTexture regions stay strictly within source PNG bounds
        atlas_oob = []
        for sid, (stype, sbody) in info["sub"].items():
            if stype == "AtlasTexture":
                am = re.search(r'atlas\s*=\s*ExtResource\("([^"]+)"\)', sbody)
                rm = re.search(r"region\s*=\s*Rect2\(([^)]+)\)", sbody)
                if am and rm and am.group(1) in info["ext"]:
                    img_path = res_to_path(info["ext"][am.group(1)][1])
                    x, y, w, h = [float(v.strip()) for v in rm.group(1).split(",")]
                    with Image.open(img_path) as im:
                        iw, ih = im.size
                    if x < 0 or y < 0 or w <= 0 or h <= 0 or x + w > iw or y + h > ih:
                        atlas_oob.append(f"{sid}:({x},{y},{w},{h}) vs ({iw},{ih})")
        if any(st == "AtlasTexture" for st, _ in info["sub"].values()):
            check(len(atlas_oob) == 0, f"{rel}: all AtlasTexture regions fit cleanly inside PNG dimensions")

        # For .tscn files: verify parent paths and every @onready $NodePath in attached scripts!
        if info["kind"] == "gd_scene":
            bad_parents = []
            for npath, ndata in info["nodes"].items():
                parent = ndata["parent"]
                if parent is not None and parent != "." and parent not in info["nodes"]:
                    bad_parents.append(f"{npath} (missing parent {parent})")
            check(len(bad_parents) == 0, f"{rel}: all {len(info['nodes'])} scene nodes have valid parent paths")

            for npath, ndata in info["nodes"].items():
                scr_ext = ndata["script_ext"]
                if scr_ext and scr_ext in info["ext"]:
                    scr_path = res_to_path(info["ext"][scr_ext][1])
                    scr_text = scr_path.read_text(encoding="utf-8")
                    dollar_paths = re.findall(r"@onready\s+var\s+\w+[^=]*=\s*\$([A-Za-z0-9_/]+)", scr_text)
                    missing_nodes = []
                    for dp in dollar_paths:
                        full_dp = dp if npath == "." else f"{npath}/{dp}"
                        if full_dp not in info["nodes"]:
                            missing_nodes.append(full_dp)
                    if dollar_paths:
                        check(
                            len(missing_nodes) == 0,
                            f"{rel} ({scr_path.name}): all {len(dollar_paths)} @onready $NodePaths resolve (missing: {missing_nodes})",
                        )

    # Specifically verify all required animations inside stickman_sprite_frames.tres
    sf_text = (ROOT / "resources/sprites/stickman_sprite_frames.tres").read_text(encoding="utf-8")
    defined_anims = set(re.findall(r'"name":\s*&"([^"]+)"', sf_text))
    missing_anims = [a for a in REQUIRED_ANIMATIONS if a not in defined_anims]
    check(len(missing_anims) == 0, f"All {len(REQUIRED_ANIMATIONS)} Side-Scroll & Top-Down animations defined in SpriteFrames")


def validate_data_and_localization() -> None:
    print("\n--- 5. Data Config & Bilingual (EN / AR RTL) Localization ---")
    en_path = ROOT / "data/localization/en.json"
    ar_path = ROOT / "data/localization/ar.json"
    cfg_path = ROOT / "data/config/movement_config.json"

    en = json.loads(en_path.read_text(encoding="utf-8"))
    ar = json.loads(ar_path.read_text(encoding="utf-8"))
    cfg = json.loads(cfg_path.read_text(encoding="utf-8"))

    en_keys = set(en.keys())
    ar_keys = set(ar.keys())
    check(en_keys == ar_keys and len(en_keys) >= 35, f"EN/AR localization tables have 100% key parity ({len(en_keys)} keys)")
    check(en.get("meta.direction") == "ltr" and ar.get("meta.direction") == "rtl", "EN=ltr and AR=rtl metadata verified")

    empty_vals = [k for k in en_keys if not str(en[k]).strip() or not str(ar[k]).strip()]
    check(len(empty_vals) == 0, "Zero empty localization strings in EN or AR")

    # Verify placeholder token parity (e.g., {count})
    token_mismatch = []
    for k in en_keys:
        t_en = set(re.findall(r"\{(\w+)\}", str(en[k])))
        t_ar = set(re.findall(r"\{(\w+)\}", str(ar[k])))
        if t_en != t_ar:
            token_mismatch.append(k)
    check(len(token_mismatch) == 0, "100% format placeholder parity between EN and AR")

    # Verify authentic Unicode Arabic codepoints (U+0600..U+06FF) and no pre-shaped presentation forms
    arabic_entries = sum(1 for k, v in ar.items() if any("\u0600" <= ch <= "\u06ff" for ch in str(v)))
    pres_forms = sum(1 for v in ar.values() for ch in str(v) if "\ufe70" <= ch <= "\ufeff")
    check(arabic_entries >= len(ar_keys) - 3, f"Arabic table contains genuine UTF-8 Arabic script ({arabic_entries}/{len(ar_keys)} keys)")
    check(pres_forms == 0, "Arabic strings use standard logical Unicode (no broken presentation-form hacks)")

    # Verify every translate_key("...") literal in scripts exists in en.json & ar.json
    missing_used_keys = []
    for gd in ROOT.rglob("*.gd"):
        src = gd.read_text(encoding="utf-8")
        for m in re.finditer(r'translate_key\(\s*"([a-z0-9_.]+)"', src):
            key = m.group(1)
            if key not in en_keys:
                missing_used_keys.append(f"{gd.name}:{key}")
    check(len(missing_used_keys) == 0, f"Every translate_key() literal in scripts exists in localization JSONs (missing: {missing_used_keys})")

    # Dynamic movement state.* keys & interactive lore_key bindings
    dyn_states: set[str] = set()
    for gd in (ROOT / "scripts/player").glob("*.gd"):
        src = gd.read_text(encoding="utf-8")
        dyn_states |= set(re.findall(r'_set_state_key\("(\w+)"\)', src))
        for a, b in re.findall(r'_set_state_key\("(\w+)"\s+if\s+[^)]+else\s+"(\w+)"\)', src):
            dyn_states.add(a)
            dyn_states.add(b)
        dyn_states |= set(re.findall(r'_last_air_jump_state(?:\s*:\s*String)?\s*=\s*"(\w+)"', src))
    missing_states = [f"state.{s}" for s in sorted(dyn_states) if f"state.{s}" not in en_keys]
    check(
        len(missing_states) == 0 and len(dyn_states) >= 12,
        f"All {len(dyn_states)} dynamic movement state.* keys exist in EN & AR (missing: {missing_states})",
    )

    lore_keys: set[str] = set()
    for p in list(ROOT.rglob("*.tscn")) + list(ROOT.rglob("*.gd")):
        lore_keys |= set(re.findall(r'lore_key(?:\s*:\s*String)?\s*=\s*"([^"]+)"', p.read_text(encoding="utf-8")))
    missing_lore = [k for k in sorted(lore_keys) if k not in en_keys]
    check(
        len(missing_lore) == 0 and len(lore_keys) >= 2,
        f"All {len(lore_keys)} interactive lore_key entries exist in EN & AR (missing: {missing_lore})",
    )

    # Validate movement_config.json sanity
    ss = cfg.get("side_scroll", {})
    td = cfg.get("top_down", {})
    check(ss.get("move_speed", 0) > 0 and ss.get("gravity", 0) > 0 and ss.get("jump_velocity", 0) < 0, "Side-scroll physics config values valid")
    check(ss.get("max_jumps", 0) == 2 and ss.get("dodge_speed", 0) > ss.get("move_speed", 0), "Double jump and dodge speed valid")
    check(td.get("move_speed", 0) > 0 and td.get("dodge_speed", 0) > td.get("move_speed", 0), "Top-down movement config values valid")


def validate_assets_and_licenses() -> None:
    print("\n--- 6. Art Assets, Fonts & License Records ---")
    pngs = sorted((ROOT / "assets/sprites").rglob("*.png"))
    check(len(pngs) >= 18, f"Found {len(pngs)} generated sprite/environment/UI PNG assets")
    bad_pngs = []
    for p in pngs:
        try:
            with Image.open(p) as im:
                im.verify()
            with Image.open(p) as im:
                if im.mode != "RGBA" or im.size[0] < 32 or im.size[1] < 32:
                    bad_pngs.append(str(p.relative_to(ROOT)))
        except Exception as exc:
            bad_pngs.append(f"{p.name}:{exc}")
    check(len(bad_pngs) == 0, f"All {len(pngs)} PNG assets pass binary verification and RGBA mode check")

    font_path = ROOT / "assets/fonts/Cairo-VariableFont.ttf"
    font = ImageFont.truetype(str(font_path), 24)
    check(font.getname()[0] == "Cairo", "Bundled Cairo Arabic/Latin TrueType font loads cleanly")

    svg_root = ET.parse(ROOT / "icon.svg").getroot()
    check(svg_root.tag.endswith("svg"), "icon.svg parses as valid XML SVG")

    check((ROOT / "licenses/OFL-1.1-Cairo.txt").is_file(), "licenses/OFL-1.1-Cairo.txt present")
    check((ROOT / "licenses/CC0-1.0-Shadowbound-Art.txt").is_file(), "licenses/CC0-1.0-Shadowbound-Art.txt present")


def validate_phase3_combat() -> None:
    print("\n--- 7. Phase 3 Combat Resources & Scene Contracts ---")
    cfg = json.loads((ROOT / "data/config/combat_config.json").read_text())
    check(set(cfg) == {"player_combat", "defense", "projectile", "boss"}, "Combat config has all four sections")
    steps = cfg["player_combat"]["combo_steps"]
    check([x["step"] for x in steps] == [1, 2, 3], "Sword combo has exactly three ordered steps")
    check([x["damage_multiplier"] for x in steps] == sorted(x["damage_multiplier"] for x in steps),
          "Combo damage escalates through the finisher")
    check([x["breaks_shield"] for x in steps] == [False, False, True], "Only the finisher naturally breaks shields")
    check(all(x["duration"] > 0 and x["hitbox_scale"] >= 1 and x["stamina_cost"] >= 0 for x in steps),
          "Combo timing, hitbox scales and stamina costs are valid")
    for step in steps:
        check(step["ss_anim"] in REQUIRED_ANIMATIONS and step["td_anim"] in REQUIRED_ANIMATIONS,
              f"Combo step {step['step']} binds both player animation modes")
    check(0 < cfg["boss"]["phase_3_hp_ratio"] < cfg["boss"]["phase_2_hp_ratio"] < 1,
          "Boss phase thresholds descend strictly inside HP range")
    check(cfg["boss"]["fan_orb_count"] == 3 and cfg["boss"]["nova_orb_count"] == 8,
          "Boss fan and radial nova projectile counts are configured")
    check(0 < cfg["defense"]["block_damage_reduction"] < 1 and cfg["defense"]["block_stamina_cost"] > 0,
          "Guard mitigates damage at a positive stamina cost")
    check(cfg["defense"]["revive_delay"] > 0 and cfg["defense"]["hurt_invuln_duration"] > 0,
          "Revive and hurt immunity durations are positive")
    base_src = (ROOT / "scripts/enemies/enemy_base.gd").read_text()
    inherited_paths = re.findall(r'@onready\s+var\s+\w+[^=]*=\s*\$([A-Za-z0-9_/]+)', base_src)
    loc = json.loads((ROOT / "data/localization/en.json").read_text())
    actors = ["umbral_hound", "rift_wisp", "obsidian_sentinel", "eclipse_warden"]
    for actor in actors:
        scene_name = actor + ("_boss" if actor == "eclipse_warden" else "")
        scene = parse_godot_text_resource(ROOT / f"scenes/enemies/{scene_name}.tscn")
        check(all(path in scene["nodes"] for path in inherited_paths), f"{actor}: inherited EnemyBase NodePaths resolve")
        hurtbox = re.search(r'\[node name="Hurtbox"[^\n]*\]([^\[]+)', scene["raw"])
        check(hurtbox is not None and "collision_layer = 16" in hurtbox[1]
              and "collision_mask = 0" in hurtbox[1] and 'groups=["enemy_hurtbox"]' in hurtbox[0],
              f"{actor}: hurtbox is a monitorable layer-16 enemy_hurtbox")
        stats = (ROOT / f"resources/combat/{actor}_stats.tres").read_text()
        name = re.search(r'^name_key = "([^"]+)"', stats, re.M)[1]
        check(name in loc, f"{actor}: EnemyStats display name is localized")
        frames = (ROOT / f"resources/sprites/{actor}_frames.tres").read_text()
        expected = {"idle", "move", "attack", "phase_shift" if actor == "eclipse_warden" else "hurt"}
        check(set(re.findall(r'"name":\s*&"([^"]+)"', frames)) == expected,
              f"{actor}: all four AI animation states are defined")
    player = parse_godot_text_resource(ROOT / "scenes/player/player.tscn")
    check("collision_mask = 88" in player["raw"], "Player slash sees enemy hurtboxes, totems, and hostile orbs")
    check((ROOT / "tests/gdscript/test_phase3_runner.tscn").is_file(), "Native Phase 3 regression runner exists")


def main() -> int:
    print("=======================================================")
    print("  SHADOWBOUND — Automated Project Validation Runner")
    print("=======================================================")
    validate_structure_and_security()
    autoloads = validate_project_godot()
    validate_gdscripts(autoloads)
    validate_scenes_and_resources()
    validate_data_and_localization()
    validate_assets_and_licenses()
    validate_phase3_combat()

    print("\n=======================================================")
    print(f"  SUMMARY: {passed} passed, {failed} failed")
    print("=======================================================")
    if failures:
        print("Failed checks:")
        for f in failures:
            print(f"  - {f}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
