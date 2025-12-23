#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent


def _format_duration(seconds: float) -> str:
    if seconds < 1:
        return f"{seconds * 1000:.1f}ms"
    if seconds < 10:
        return f"{seconds:.2f}s"
    return f"{seconds:.1f}s"


def _safe_print(message: str, *, file=sys.stdout) -> None:
    try:
        print(message, file=file, flush=True)
    except BrokenPipeError:
        raise SystemExit(0)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run `tuist generate` with filtered, phase-based logging."
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Pass through full Tuist output.",
    )
    args, forwarded = parser.parse_known_args()

    cmd = ["tuist", "generate", *forwarded]
    start = time.perf_counter()

    workspace: str | None = None
    time_taken: str | None = None
    project_names: list[str] = []
    cached_targets: list[str] = []

    printed: set[str] = set()
    collecting_cached = False

    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        delete=False,
        prefix="tuist-generate.",
        suffix=".log",
    ) as log_file:
        log_path = Path(log_file.name)

        if not args.verbose:
            _safe_print("🔃 tuist generate: start")

        proc = subprocess.Popen(
            cmd,
            cwd=str(REPO_ROOT),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )

        assert proc.stdout is not None
        for line in proc.stdout:
            log_file.write(line)

            if args.verbose:
                try:
                    sys.stdout.write(line)
                    sys.stdout.flush()
                except BrokenPipeError:
                    proc.stdout.close()
                    proc.terminate()
                    return 0

            stripped = line.strip()
            if not stripped:
                collecting_cached = False
                continue

            if "Loading and constructing the graph" in stripped:
                if not args.verbose and "graph" not in printed:
                    printed.add("graph")
                    _safe_print("🔃 tuist generate: graph…")
                continue

            if stripped.startswith("Using cache binaries for the following targets:"):
                if not args.verbose and "cache" not in printed:
                    printed.add("cache")
                    _safe_print("🔃 tuist generate: cache…")

                collecting_cached = True
                suffix = stripped.split(":", 1)[1].strip()
                if suffix:
                    cached_targets.extend(
                        [token.strip(",") for token in suffix.split() if token.strip(",")]
                    )
                continue

            if collecting_cached:
                if (
                    stripped.startswith("Generating workspace ")
                    or stripped.startswith("Generating project ")
                    or stripped.startswith("Total time taken:")
                ):
                    collecting_cached = False
                else:
                    cached_targets.extend(
                        [token.strip(",") for token in stripped.split() if token.strip(",")]
                    )
                    continue

            workspace_match = re.match(r"^Generating workspace (.+)$", stripped)
            if workspace_match:
                workspace = workspace_match.group(1).strip()
                if not args.verbose:
                    _safe_print(f"🔃 tuist generate: workspace {workspace}")
                continue

            project_match = re.match(r"^Generating project (.+)$", stripped)
            if project_match:
                project_names.append(project_match.group(1).strip())
                if not args.verbose and "projects" not in printed:
                    printed.add("projects")
                    _safe_print("🔃 tuist generate: projects…")
                continue

            time_match = re.match(r"^Total time taken:\s*(.+)$", stripped)
            if time_match:
                time_taken = time_match.group(1).strip()
                continue

        exit_code = proc.wait()

    elapsed = time.perf_counter() - start

    if exit_code != 0:
        _safe_print(f"🔃 tuist generate: failed (exit {exit_code})")
        try:
            sys.stdout.write(log_path.read_text(encoding="utf-8"))
        except BrokenPipeError:
            return 0
        finally:
            log_path.unlink(missing_ok=True)
        return exit_code

    duration_str = time_taken or _format_duration(elapsed)
    extras: list[str] = []
    if project_names:
        extras.append(f"projects={len(project_names)}")
    if cached_targets:
        extras.append(f"cached={len(cached_targets)}")

    extras_str = f" [{', '.join(extras)}]" if extras else ""
    workspace_str = f" → {workspace}" if workspace else ""

    _safe_print(f"🔃 tuist generate: done ({duration_str}){extras_str}{workspace_str}")
    log_path.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
