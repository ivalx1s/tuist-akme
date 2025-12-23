#!/usr/bin/env python3

from __future__ import annotations

import re
import sys
import time
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
MODULES_ROOT = REPO_ROOT / "Modules"
OUTPUT_FILE = REPO_ROOT / "Tuist" / "ProjectDescriptionHelpers" / "Modules+Generated.swift"


LAYERS: list[tuple[str, str]] = [
    ("Features", "FeatureLayer"),
    ("Core", "CoreLayer"),
    ("Shared", "SharedLayer"),
    ("Utility", "UtilityLayer"),
]


SWIFT_KEYWORDS: set[str] = {
    # Declarations
    "associatedtype",
    "class",
    "deinit",
    "enum",
    "extension",
    "fileprivate",
    "func",
    "import",
    "init",
    "inout",
    "internal",
    "let",
    "open",
    "operator",
    "private",
    "protocol",
    "public",
    "rethrows",
    "static",
    "struct",
    "subscript",
    "typealias",
    "var",
    # Statements
    "break",
    "case",
    "continue",
    "default",
    "defer",
    "do",
    "else",
    "fallthrough",
    "for",
    "guard",
    "if",
    "in",
    "repeat",
    "return",
    "switch",
    "where",
    "while",
    # Expressions / literals
    "as",
    "catch",
    "false",
    "is",
    "nil",
    "self",
    "Self",
    "super",
    "throw",
    "throws",
    "true",
    "try",
    # Contextual keywords (common)
    "any",
    "some",
    "nonisolated",
    "isolated",
    "actor",
    "async",
    "await",
    "consuming",
    "discard",
    "distributed",
    "macro",
    "mutating",
    "nonmutating",
    "override",
    "required",
    "optional",
    "lazy",
    "weak",
    "unowned",
}


@dataclass(frozen=True)
class ModuleCase:
    case_name: str
    raw_value: str


_VALID_MODULE_DIR_RE = re.compile(r"^[A-Za-z][A-Za-z0-9]*$")


def _to_lower_camel(pascal: str) -> str:
    if not pascal:
        raise ValueError("Empty module name.")

    # If it's all-uppercase (digits ignored by str.isupper), lowercase everything.
    if pascal.isupper():
        return pascal.lower()

    # Find leading run of capitals.
    i = 0
    while i < len(pascal) and pascal[i].isupper():
        i += 1

    if i <= 1:
        return pascal[0].lower() + pascal[1:]

    # If the next char is lowercase, split before the last capital.
    if i < len(pascal) and pascal[i].islower():
        return pascal[: i - 1].lower() + pascal[i - 1 :]

    return pascal[:i].lower() + pascal[i:]


def _swift_identifier(module_dir_name: str) -> str:
    if not _VALID_MODULE_DIR_RE.match(module_dir_name):
        raise ValueError(
            f"Invalid module folder name '{module_dir_name}'. "
            "Expected only letters/digits and starting with a letter (e.g. 'Auth', 'URLSession')."
        )

    identifier = _to_lower_camel(module_dir_name)

    # Guard against starting with a digit (shouldn't happen with the regex), and keywords.
    if identifier and identifier[0].isdigit():
        identifier = f"_{identifier}"
    if identifier in SWIFT_KEYWORDS:
        identifier = f"{identifier}_"

    return identifier


def _scan_layer(layer_folder: str) -> list[ModuleCase]:
    path = MODULES_ROOT / layer_folder
    if not path.exists():
        return []

    module_dirs = sorted(
        [p.name for p in path.iterdir() if p.is_dir() and not p.name.startswith(".")]
    )

    cases: list[ModuleCase] = []
    seen: dict[str, str] = {}
    for module_dir in module_dirs:
        case_name = _swift_identifier(module_dir)
        if case_name in seen:
            raise ValueError(
                f"Duplicate Swift case name '{case_name}' in Modules/{layer_folder}: "
                f"'{seen[case_name]}' and '{module_dir}'."
            )
        seen[case_name] = module_dir
        cases.append(ModuleCase(case_name=case_name, raw_value=module_dir))

    return cases


def _generate_enum(enum_name: str, layer_folder: str, cases: list[ModuleCase]) -> str:
    lines: list[str] = [
        f"public enum {enum_name}: String, CaseIterable, Sendable {{",
    ]

    if not cases:
        lines += [
            f"    // No modules found in Modules/{layer_folder}/",
            '    @available(*, unavailable, message: "No modules found in this layer.")',
            '    case __none = "__none"',
            "",
            f"    public static var allCases: [{enum_name}] {{ [] }}",
            "}",
        ]
        return "\n".join(lines)

    for module_case in cases:
        lines.append(f'    case {module_case.case_name} = "{module_case.raw_value}"')

    lines.append("}")
    return "\n".join(lines)


def _format_duration(seconds: float) -> str:
    if seconds < 1:
        return f"{seconds * 1000:.1f}ms"
    if seconds < 10:
        return f"{seconds:.2f}s"
    return f"{seconds:.1f}s"


def main() -> int:
    start = time.perf_counter()
    try:
        print("🔄 sync-modules: start", flush=True)

        output_dir = OUTPUT_FILE.parent
        output_dir.mkdir(parents=True, exist_ok=True)

        content_lines: list[str] = [
            "import Foundation",
            "// AUTO-GENERATED - DO NOT EDIT.",
            "// Generated by `python3 Scripts/sync_modules.py` from the `Modules/` directory.",
            "",
        ]

        layer_case_counts: dict[str, int] = {}
        for layer_folder, enum_name in LAYERS:
            cases = _scan_layer(layer_folder)
            layer_case_counts[layer_folder] = len(cases)
            content_lines.append(_generate_enum(enum_name, layer_folder, cases))
            content_lines.append("")

        new_content = "\n".join(content_lines).rstrip() + "\n"

        unchanged = False
        if OUTPUT_FILE.exists():
            existing = OUTPUT_FILE.read_text(encoding="utf-8")
            unchanged = existing == new_content

        if not unchanged:
            OUTPUT_FILE.write_text(new_content, encoding="utf-8")

        elapsed_s = time.perf_counter() - start
        elapsed_str = _format_duration(elapsed_s)
        counts_str = ", ".join(
            f"{layer.lower()}={count}" for layer, count in layer_case_counts.items()
        )
        status = "up-to-date" if unchanged else "updated"
        print(
            f"🔄 sync-modules: done ({status}, {elapsed_str}) [{counts_str}] → {OUTPUT_FILE.relative_to(REPO_ROOT)}"
        )
        return 0
    except Exception as exc:
        elapsed_s = time.perf_counter() - start
        print(
            f"🔄 sync-modules: failed ({_format_duration(elapsed_s)}): {exc}", file=sys.stderr
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
