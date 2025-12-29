#!/usr/bin/env python3

"""
sync_portal_capabilities.py

Generates `Capability.PortalCapability` from Xcode's bundled portal capability catalog.

This script is intended for the project's Tuist manifest / plugin DSL layer only (not app source).
It reads `DVTPortalCachedPortalCapabilities.json` from the active Xcode installation and writes:

- TuistPlugins/ProjectInfraPlugin/ProjectDescriptionHelpers/Capability+PortalCapability.swift

Run:
  python3 Scripts/sync_portal_capabilities.py
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_SWIFT = (
    REPO_ROOT
    / "TuistPlugins"
    / "ProjectInfraPlugin"
    / "ProjectDescriptionHelpers"
    / "Capability+PortalCapability.swift"
)


def _developer_dir() -> Path:
    import os

    if developer_dir := os.environ.get("DEVELOPER_DIR"):
        return Path(developer_dir)

    try:
        out = subprocess.check_output(["/usr/bin/xcode-select", "-p"], text=True).strip()
        if out:
            return Path(out)
    except Exception as e:
        raise RuntimeError(f"Failed to resolve Xcode developer directory: {e}") from e

    raise RuntimeError("Could not resolve Xcode developer directory (DEVELOPER_DIR / xcode-select -p).")


def _portal_capabilities_json_path() -> Path:
    developer_dir = _developer_dir()
    contents_dir = developer_dir.parent if developer_dir.name == "Developer" else developer_dir
    json_path = (
        contents_dir
        / "SharedFrameworks"
        / "DVTPortal.framework"
        / "Versions"
        / "A"
        / "Resources"
        / "DVTPortalCachedPortalCapabilities.json"
    )
    if not json_path.exists():
        raise RuntimeError(f"Portal capabilities JSON not found at {json_path}")
    return json_path


def _swift_case_name(display_name: str) -> str:
    # Strip parenthetical suffixes like "(development)".
    name = re.sub(r"\s*\([^)]*\)", "", display_name)
    # Replace punctuation with spaces.
    name = re.sub(r"[^0-9A-Za-z]+", " ", name)
    words = [w for w in name.strip().split() if w]
    if not words:
        raise ValueError(display_name)

    acronyms = {"ID", "NFC", "HLS", "VPN", "SIM", "MDM", "URL"}

    def is_mixed_case(w: str) -> bool:
        return w.lower() != w and w.upper() != w

    def transform_word(w: str) -> str:
        upper = w.upper()
        if upper == "5G":
            return "FiveG"
        if upper in acronyms:
            return upper
        if is_mixed_case(w):
            return w
        if upper == "WIFI":
            return "WiFi"
        if upper == "MACOS":
            return "macOS"
        return w.capitalize()

    upper_camel = "".join([transform_word(words[0])] + [transform_word(w) for w in words[1:]])
    upper_camel = upper_camel.replace("Macos", "macOS")

    if not upper_camel:
        return upper_camel
    if upper_camel[0].islower():
        return upper_camel

    # Convert UpperCamel to lowerCamel, handling leading acronym runs: URLSession -> urlSession.
    run_end = 0
    while run_end < len(upper_camel) and upper_camel[run_end].isupper():
        run_end += 1
    if run_end <= 1:
        return upper_camel[0].lower() + upper_camel[1:]
    return upper_camel[: run_end - 1].lower() + upper_camel[run_end - 1 :]


def main() -> int:
    json_path = _portal_capabilities_json_path()
    payload = json.loads(json_path.read_text(encoding="utf-8"))
    items = payload.get("data", [])

    entries: list[tuple[str, str, str]] = []
    for item in items:
        cap_id = item.get("id")
        name = (item.get("attributes") or {}).get("name")
        if not cap_id or not name:
            continue
        case_name = _swift_case_name(name)
        entries.append((case_name, cap_id, name))

    entries.sort(key=lambda t: t[0])

    # Ensure uniqueness of case names.
    seen: dict[str, tuple[str, str]] = {}
    for case_name, cap_id, name in entries:
        if case_name in seen:
            prev_id, prev_name = seen[case_name]
            raise RuntimeError(
                f"Case name collision for '{case_name}': {prev_id} ({prev_name}) vs {cap_id} ({name})"
            )
        seen[case_name] = (cap_id, name)

    lines: list[str] = []
    lines.append("/// Portal capability identifiers derived from Xcode.")
    lines.append("///")
    lines.append("/// This file is generated from Xcode's bundled portal capability definitions.")
    lines.append("/// Do not edit by hand; regenerate from the current Xcode installation.")
    lines.append("///")
    lines.append("/// Source: `DVTPortalCachedPortalCapabilities.json` inside the active Xcode installation.")
    lines.append("extension Capability {")
    lines.append("    /// Apple Developer portal “App ID capabilities” (a.k.a. managed capabilities).")
    lines.append("    ///")
    lines.append("    /// Use these when you need to enable an Apple service via entitlements but don't want")
    lines.append("    /// to model a dedicated high-level API yet. Some capabilities require extra configuration")
    lines.append("    /// (for example, selecting values or providing identifiers) and will be rejected by")
    lines.append("    /// `EntitlementsFactory` unless a dedicated helper exists.")
    lines.append("    public enum PortalCapability: String, CaseIterable, Hashable, Sendable {")
    for case_name, cap_id, name in entries:
        lines.append(f'        case {case_name} = "{cap_id}" // {name}')
    lines.append("    }")
    lines.append("}")
    lines.append("")

    OUTPUT_SWIFT.write_text("\n".join(lines), encoding="utf-8")
    print(f"✅ portal capabilities: wrote {OUTPUT_SWIFT.relative_to(REPO_ROOT)} ({len(entries)} cases)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
