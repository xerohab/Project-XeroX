#!/usr/bin/env python3

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import os
from pathlib import Path


ALWAYS_IGNORE = (
    ".git",
    ".git/*",
    "node_modules",
    "node_modules/*",
    "vendor",
    "vendor/*",
)


def digest(path: Path) -> str:
    h = hashlib.sha256()

    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)

    return h.hexdigest()


def load_patterns(path: Path) -> list[str]:
    patterns = list(ALWAYS_IGNORE)

    if path.exists():
        for raw in path.read_text(encoding="utf-8").splitlines():
            raw = raw.strip()

            if not raw or raw.startswith("#"):
                continue

            patterns.append(raw)

    return patterns


def matches(rel: str, patterns: list[str]) -> bool:
    rel = rel.replace(os.sep, "/")

    for pattern in patterns:
        p = pattern.replace("\\", "/")

        if p.endswith("/"):
            base = p.rstrip("/")

            if rel == base or rel.startswith(base + "/"):
                return True

        if fnmatch.fnmatch(rel, p):
            return True

    return False


def inventory(root: Path) -> dict[str, Path]:
    result: dict[str, Path] = {}

    if not root.exists():
        return result

    for path in root.rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue

        rel = path.relative_to(root).as_posix()

        if matches(rel, list(ALWAYS_IGNORE)):
            continue

        result[rel] = path

    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--component", required=True)
    parser.add_argument("--source", required=True)
    parser.add_argument("--destination", required=True)
    parser.add_argument("--protection", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument(
        "--selective",
        action="store_true",
        help="Do not classify files as automatically deployable.",
    )

    args = parser.parse_args()

    source = Path(args.source).resolve()
    destination = Path(args.destination).resolve()
    protection_file = Path(args.protection).resolve()
    output = Path(args.output).resolve()

    patterns = load_patterns(protection_file)

    src = inventory(source)
    dst = inventory(destination)

    source_paths = set(src)
    destination_paths = set(dst)

    added = sorted(source_paths - destination_paths)
    destination_only = sorted(destination_paths - source_paths)

    common = sorted(source_paths & destination_paths)

    changed = []
    identical = []

    for rel in common:
        try:
            same = (
                src[rel].stat().st_size == dst[rel].stat().st_size
                and digest(src[rel]) == digest(dst[rel])
            )
        except OSError:
            same = False

        if same:
            identical.append(rel)
        else:
            changed.append(rel)

    candidate = []
    protected = []

    for status, paths in (
        ("ADD", added),
        ("CHANGE", changed),
    ):
        for rel in paths:
            if args.selective or matches(rel, patterns):
                protected.append((status, rel))
            else:
                candidate.append((status, rel))

    output.parent.mkdir(parents=True, exist_ok=True)

    with output.open("w", encoding="utf-8") as f:
        f.write("PROJECT_XEROX_COMPARISON=1\n")
        f.write(f"COMPONENT={args.component}\n")
        f.write(f"SOURCE={source}\n")
        f.write(f"DESTINATION={destination}\n")
        f.write(f"SELECTIVE={'YES' if args.selective else 'NO'}\n")
        f.write("READ_ONLY=YES\n\n")

        f.write("===== SUMMARY =====\n")
        f.write(f"SOURCE_FILES={len(source_paths)}\n")
        f.write(f"DESTINATION_FILES={len(destination_paths)}\n")
        f.write(f"IDENTICAL={len(identical)}\n")
        f.write(f"ADDED_IN_RELEASE={len(added)}\n")
        f.write(f"CHANGED={len(changed)}\n")
        f.write(f"DESTINATION_ONLY={len(destination_only)}\n")
        f.write(f"DEPLOY_CANDIDATES={len(candidate)}\n")
        f.write(f"PROTECTED_OR_REVIEW={len(protected)}\n\n")

        f.write("===== DEPLOY CANDIDATES =====\n")

        if candidate:
            for status, rel in candidate:
                f.write(f"{status}\t{rel}\n")
        else:
            f.write("NONE\n")

        f.write("\n===== PROTECTED / MANUAL REVIEW =====\n")

        if protected:
            for status, rel in protected:
                f.write(f"{status}\t{rel}\n")
        else:
            f.write("NONE\n")

        f.write("\n===== DESTINATION-ONLY FILES — NEVER AUTO DELETE =====\n")

        if destination_only:
            for rel in destination_only:
                f.write(f"KEEP\t{rel}\n")
        else:
            f.write("NONE\n")

    print(f"COMPONENT={args.component}")
    print(f"DEPLOY_CANDIDATES={len(candidate)}")
    print(f"PROTECTED_OR_REVIEW={len(protected)}")
    print(f"DESTINATION_ONLY={len(destination_only)}")
    print(f"REPORT={output}")
    print("READ_ONLY=YES")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
