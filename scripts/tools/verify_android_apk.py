#!/usr/bin/env python3
"""Validate the actual exported APK using SDK-tool output and ZIP contents."""
import re
import sys
import zipfile
from pathlib import Path


def main() -> None:
    apk, logs = map(Path, sys.argv[1:3])
    badging = (logs / "badging.log").read_text()
    permissions = (logs / "permissions.log").read_text()
    signature = (logs / "signature.log").read_text()
    assert "Verifies" in signature, "APK signature verification did not succeed"
    assert "name='com.shadowbound.rpg'" in badging, "Unexpected package ID"
    project = Path(__file__).resolve().parents[2] / "project.godot"
    version = re.search(r'config/version="([0-9]+\.[0-9]+\.[0-9]+)"', project.read_text())[1]
    assert f"versionName='{version}-preview'" in badging, "Unexpected version"
    assert "sdkVersion:'28'" in badging, "Minimum Android version must be API 28"
    assert "targetSdkVersion:'34'" in badging, "Target SDK must be API 34"
    native = re.search(r"^native-code: (.+)$", badging, re.M)
    assert native and {"'armeabi-v7a'", "'arm64-v8a'"} <= set(native[1].split()), "Missing ARM architecture"
    assert "launchable-activity:" in badging, "No launchable Android activity"
    assert not re.search(r"^uses-permission", permissions, re.M), "Unexpected Android permissions"
    with zipfile.ZipFile(apk) as archive:
        assert archive.testzip() is None, "Corrupted APK ZIP entry"
        names = archive.namelist()
        assert "AndroidManifest.xml" in names, "Missing manifest"
        assert any(n.startswith("lib/arm64-v8a/") and n.endswith(".so") for n in names), "Missing ARM64 engine"
        assert any(n.startswith("lib/armeabi-v7a/") and n.endswith(".so") for n in names), "Missing ARMv7 engine"
        for suffix in ["project.binary", "data/config/combat_config.json", "data/localization/ar.json",
                       "data/config/progression_config.json", "data/items/item_catalog.json"]:
            assert any(n.endswith(suffix) for n in names), f"Missing game resource: {suffix}"
        assert not any(n.endswith((".keystore", ".jks", ".py")) for n in names), "Build tool or signing key leaked"
    print(f"PASS: {apk.name}: signature, manifest, SDK, ARM libraries, offline permissions and resources")


if __name__ == "__main__":
    main()
