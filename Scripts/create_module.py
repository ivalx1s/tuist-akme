#!/usr/bin/env python3

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from sync_modules import MODULES_ROOT, REPO_ROOT, _swift_identifier


LAYER_TO_FOLDER: dict[str, str] = {
    "feature": "Features",
    "core": "Core",
    "shared": "Shared",
    "utility": "Utility",
}


def _write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n", encoding="utf-8")


def _render_project_swift(layer: str, module_name: str) -> str:
    case_name = _swift_identifier(module_name)
    return f"""@preconcurrency import ProjectDescription
@preconcurrency import ProjectInfraPlugin
@preconcurrency import ProjectDescriptionHelpers

let module = ModuleID.{layer}(.{case_name})

let project = ProjectFactory.makeFeature(
    module: module,
    destinations: Destinations.iOS.union(Destinations.macOS),
    product: .framework,
    dependencies: [],
    testDependencies: []
)
"""


def _render_interface_swift(module_name: str) -> str:
    return f"""public protocol {module_name}Service {{
    func ping() -> String
}}
"""


def _render_impl_swift(module_name: str) -> str:
    return f"""import {module_name}Interface

public final class {module_name}ServiceImpl: {module_name}Service {{
    public init() {{}}

    public func ping() -> String {{ "pong" }}
}}
"""


def _render_testing_swift(module_name: str) -> str:
    return f"""import {module_name}Interface

public final class Mock{module_name}Service: {module_name}Service {{
    public var pingResult: String

    public init(pingResult: String = "mock") {{
        self.pingResult = pingResult
    }}

    public func ping() -> String {{ pingResult }}
}}
"""


def _render_tests_swift(module_name: str) -> str:
    return f"""import XCTest
import {module_name}

final class {module_name}Tests: XCTestCase {{
    func testPing() {{
        XCTAssertEqual({module_name}ServiceImpl().ping(), "pong")
    }}
}}
"""


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a new module folder with a Project.swift and basic targets."
    )
    parser.add_argument(
        "--layer",
        required=True,
        choices=sorted(LAYER_TO_FOLDER.keys()),
        help="Module layer (feature/core/shared/utility).",
    )
    parser.add_argument(
        "--name",
        required=True,
        help="Module name (e.g. Auth, Networking, URLSession).",
    )

    args = parser.parse_args()
    layer = args.layer.strip().lower()
    module_name = args.name.strip()

    # Validate module name by attempting to derive a Swift identifier (raises on invalid).
    _swift_identifier(module_name)

    layer_folder = LAYER_TO_FOLDER[layer]
    module_dir = MODULES_ROOT / layer_folder / module_name

    if module_dir.exists():
        print(f"Already exists: {module_dir.relative_to(REPO_ROOT)}", file=sys.stderr)
        return 1

    # Create folder structure.
    (module_dir / "Interface").mkdir(parents=True, exist_ok=False)
    (module_dir / "Sources").mkdir(parents=True, exist_ok=False)
    (module_dir / "Testing").mkdir(parents=True, exist_ok=False)
    (module_dir / "Tests").mkdir(parents=True, exist_ok=False)

    # Seed initial sources so the targets can build.
    _write_file(module_dir / "Project.swift", _render_project_swift(layer, module_name))
    _write_file(module_dir / "Interface" / f"{module_name}Service.swift", _render_interface_swift(module_name))
    _write_file(module_dir / "Sources" / f"{module_name}ServiceImpl.swift", _render_impl_swift(module_name))
    _write_file(module_dir / "Testing" / f"Mock{module_name}Service.swift", _render_testing_swift(module_name))
    _write_file(module_dir / "Tests" / f"{module_name}Tests.swift", _render_tests_swift(module_name))

    print(f"Created: {module_dir.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
