#!/usr/bin/env python3
"""Generate a single top-level shader manifest for all effects."""

import json
from pathlib import Path

EFFECTS_ROOT = Path("shaders/effects")
OUTPUT_FILE = Path("shaders/effects/manifest.json")

def scan_effect(effect_dir):
    """Scan shader files for a single effect."""
    result = {"glsl": {}, "wgsl": {}}
    
    glsl_dir = effect_dir / "glsl"
    if glsl_dir.exists():
        for f in glsl_dir.iterdir():
            if f.suffix == ".glsl":
                result["glsl"][f.stem] = "combined"
            elif f.suffix == ".vert":
                if f.stem not in result["glsl"]:
                    result["glsl"][f.stem] = {}
                if isinstance(result["glsl"][f.stem], dict):
                    result["glsl"][f.stem]["v"] = 1
            elif f.suffix == ".frag":
                if f.stem not in result["glsl"]:
                    result["glsl"][f.stem] = {}
                if isinstance(result["glsl"][f.stem], dict):
                    result["glsl"][f.stem]["f"] = 1
    
    wgsl_dir = effect_dir / "wgsl"
    if wgsl_dir.exists():
        for f in wgsl_dir.iterdir():
            if f.suffix == ".wgsl":
                result["wgsl"][f.stem] = 1
    
    # Clean up empty dicts
    if not result["glsl"]:
        del result["glsl"]
    if not result["wgsl"]:
        del result["wgsl"]
    
    return result if result else None

def main():
    manifest = {}
    
    for namespace in ["basics", "nd", "nm"]:
        ns_dir = EFFECTS_ROOT / namespace
        if not ns_dir.exists():
            continue
        
        for effect_dir in sorted(ns_dir.iterdir()):
            if not effect_dir.is_dir():
                continue
            if not (effect_dir / "definition.js").exists():
                continue
            
            effect_id = f"{namespace}/{effect_dir.name}"
            effect_manifest = scan_effect(effect_dir)
            if effect_manifest:
                manifest[effect_id] = effect_manifest
    
    with open(OUTPUT_FILE, "w") as f:
        json.dump(manifest, f, separators=(',', ':'), sort_keys=True)
    
    print(f"Generated {OUTPUT_FILE} ({len(manifest)} effects)")

if __name__ == "__main__":
    main()
