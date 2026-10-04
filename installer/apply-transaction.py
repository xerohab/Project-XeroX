#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def safe_path(root: Path, rel: str) -> Path:
    candidate = (root / rel).resolve()

    try:
        candidate.relative_to(root)
    except ValueError:
        raise SystemExit(f"unsafe transaction path: {rel}")

    return candidate


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--transaction", required=True)
    args = p.parse_args()

    transaction = Path(args.transaction).resolve()
    data = json.loads(transaction.read_text(encoding="utf-8"))

    source = Path(data["source"]).resolve()
    destination = Path(data["destination"]).resolve()

    if not source.is_dir() or not destination.is_dir():
        raise SystemExit("source/destination unavailable")

    changed = 0

    for op in data["operations"]:
        action = op["operation"]
        rel = op["path"]

        if action == "preserve":
            continue

        if action not in ("create", "update"):
            raise SystemExit(f"unsupported operation: {action}")

        src = safe_path(source, rel)
        dst = safe_path(destination, rel)

        if not src.is_file():
            raise SystemExit(f"transaction source missing: {rel}")

        expected = op["sha256"]

        if digest(src) != expected:
            raise SystemExit(f"source changed after planning: {rel}")

        dst.parent.mkdir(parents=True, exist_ok=True)

        tmp = dst.parent / (dst.name + ".xerox-new")
        shutil.copy2(src, tmp)

        if digest(tmp) != expected:
            tmp.unlink(missing_ok=True)
            raise SystemExit(f"copy verification failed: {rel}")

        tmp.replace(dst)

        if digest(dst) != expected:
            raise SystemExit(f"destination verification failed: {rel}")

        changed += 1
        print(f"{action.upper()}: {rel}")

    print(f"APPLIED={changed}")
    print("DESTINATION_ONLY_DELETED=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
