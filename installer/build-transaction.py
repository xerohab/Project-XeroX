#!/usr/bin/env python3

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
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


def load_patterns(path: Path | None) -> list[str]:
    result = list(ALWAYS_IGNORE)

    if path and path.exists():
        for raw in path.read_text(encoding="utf-8").splitlines():
            raw = raw.strip()
            if not raw or raw.startswith("#"):
                continue
            result.append(raw)

    return result


def load_exact(path: Path | None) -> set[str]:
    result: set[str] = set()

    if path and path.exists():
        for raw in path.read_text(encoding="utf-8").splitlines():
            raw = raw.strip()
            if not raw or raw.startswith("#"):
                continue
            result.add(raw.replace("\\", "/").lstrip("./"))

    return result


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

    for path in root.rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue

        rel = path.relative_to(root).as_posix()

        if matches(rel, list(ALWAYS_IGNORE)):
            continue

        result[rel] = path

    return result


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--component", required=True)
    p.add_argument("--source", required=True)
    p.add_argument("--destination", required=True)
    p.add_argument("--protection", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--mode", choices=("managed", "selective"), required=True)
    p.add_argument("--allowlist")
    p.add_argument("--preserve")
    args = p.parse_args()

    source = Path(args.source).resolve()
    destination = Path(args.destination).resolve()
    output = Path(args.output).resolve()

    if not source.is_dir():
        raise SystemExit(f"source missing: {source}")

    if not destination.is_dir():
        raise SystemExit(f"destination missing: {destination}")

    protection = load_patterns(Path(args.protection))
    preserve = load_exact(Path(args.preserve)) if args.preserve else set()
    allow = load_exact(Path(args.allowlist)) if args.allowlist else set()

    src = inventory(source)
    dst = inventory(destination)

    operations: list[dict] = []

    for rel in sorted(src):
        src_path = src[rel]
        dst_path = dst.get(rel)

        if rel in preserve:
            operations.append({
                "component": args.component,
                "operation": "preserve",
                "path": rel,
                "reason": "destination-integration",
            })
            continue

        if matches(rel, protection):
            operations.append({
                "component": args.component,
                "operation": "preserve",
                "path": rel,
                "reason": "protected",
            })
            continue

        if args.mode == "selective" and rel not in allow:
            continue

        if dst_path is None:
            operations.append({
                "component": args.component,
                "operation": "create",
                "path": rel,
                "sha256": digest(src_path),
            })
            continue

        if (
            src_path.stat().st_size == dst_path.stat().st_size
            and digest(src_path) == digest(dst_path)
        ):
            continue

        operations.append({
            "component": args.component,
            "operation": "update",
            "path": rel,
            "sha256": digest(src_path),
        })

    destination_only = sorted(set(dst) - set(src))

    document = {
        "format": 1,
        "component": args.component,
        "mode": args.mode,
        "source": str(source),
        "destination": str(destination),
        "operations": operations,
        "destination_only": destination_only,
        "destination_only_policy": "preserve",
    }

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(document, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    create = sum(x["operation"] == "create" for x in operations)
    update = sum(x["operation"] == "update" for x in operations)
    protected = sum(x["operation"] == "preserve" for x in operations)

    print(f"COMPONENT={args.component}")
    print(f"CREATE={create}")
    print(f"UPDATE={update}")
    print(f"PRESERVE={protected}")
    print(f"DESTINATION_ONLY_KEEP={len(destination_only)}")
    print(f"TRANSACTION={output}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
