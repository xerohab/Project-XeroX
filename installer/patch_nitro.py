#!/usr/bin/env python3

from pathlib import Path
import argparse
import shutil
import sys
import tempfile
import difflib


parser = argparse.ArgumentParser()
parser.add_argument("--nitro-root", required=True)
parser.add_argument("--package-root", required=True)
parser.add_argument("--dry-run", action="store_true")
args = parser.parse_args()

nitro = Path(args.nitro_root).resolve()
package = Path(args.package_root).resolve()

changed = []


def read(path):
    return path.read_text(encoding="utf-8")


def write(path, text):
    old = read(path)

    if old == text:
        return

    changed.append(path)

    if args.dry_run:
        print()
        print("=" * 70)
        print(f"WOULD PATCH: {path.relative_to(nitro)}")
        print("=" * 70)

        diff = difflib.unified_diff(
            old.splitlines(),
            text.splitlines(),
            fromfile=str(path.relative_to(nitro)),
            tofile=str(path.relative_to(nitro)) + " [Project XeroX]",
            lineterm=""
        )

        for line in diff:
            print(line)

        return

    path.write_text(text, encoding="utf-8")


def insert_after_once(text, anchor, addition, label):
    if addition.strip() in text:
        print(f"ALREADY PATCHED: {label}")
        return text

    count = text.count(anchor)

    if count != 1:
        raise RuntimeError(
            f"{label}: expected exactly one anchor, found {count}"
        )

    return text.replace(
        anchor,
        anchor + addition,
        1
    )


def replace_once(text, old, new, label):
    if new in text:
        print(f"ALREADY PATCHED: {label}")
        return text

    count = text.count(old)

    if count != 1:
        raise RuntimeError(
            f"{label}: expected exactly one patch target, found {count}"
        )

    return text.replace(old, new, 1)


# ------------------------------------------------------------
# App.tsx
# ------------------------------------------------------------

path = nitro / "src/App.tsx"
text = read(path)

text = insert_after_once(
    text,
    "import { MainView } from './components/MainView';",
    "\nimport { UI2Provider } from './components/ui2/UI2Context';"
    "\nimport { UI2View } from './components/ui2/UI2View';",
    "App UI2 imports"
)

old = """            {isReady && (
                <SharedHookRegistry"""

new = """            {isReady && (
                <UI2Provider>
                    <SharedHookRegistry"""

if old in text:
    text = text.replace(old, new, 1)

    close_anchor = """                    </SharedHookRegistry>
            )}"""

    close_new = """                    </SharedHookRegistry>
                </UI2Provider>
            )}"""

    if close_anchor not in text:
        raise RuntimeError(
            "App UI2 provider: opening patch matched but closing anchor did not."
        )

    text = text.replace(close_anchor, close_new, 1)

elif "<UI2Provider>" in text:
    print("ALREADY PATCHED: App UI2 provider")

else:
    raise RuntimeError(
        "App UI2 provider: compatible isReady/SharedHookRegistry anchor not found."
    )


if "<UI2View />" not in text:
    anchor = "                        <ReconnectView />"

    if text.count(anchor) != 1:
        raise RuntimeError(
            "App UI2View: ReconnectView anchor not found exactly once."
        )

    text = text.replace(
        anchor,
        anchor + "\n                        <UI2View />",
        1
    )
else:
    print("ALREADY PATCHED: App UI2View")

write(path, text)


# ------------------------------------------------------------
# index.tsx — UI2 stylesheet
# ------------------------------------------------------------

path = nitro / "src/index.tsx"
text = read(path)

if "import './css/ui2/UI2.css';" not in text:
    candidates = [
        "import './css/index.css';",
        "import './css/habbo/HabboTheme.css';"
    ]

    anchor = next((x for x in candidates if x in text), None)

    if anchor is None:
        raise RuntimeError(
            "index.tsx: could not find safe stylesheet import anchor."
        )

    text = text.replace(
        anchor,
        anchor + "\nimport './css/ui2/UI2.css';",
        1
    )
else:
    print("ALREADY PATCHED: index UI2 stylesheet")

write(path, text)


# ------------------------------------------------------------
# Avatar editor selector
#
# This is intentionally a tiny controlled integration file.
# We do not copy the Solace selector from the package.
# ------------------------------------------------------------

path = nitro / "src/components/avatar-editor/AvatarEditorSelectorView.tsx"
text = read(path)

if "AvatarEditorUI2View" not in text:
    # Preserve the existing FC import if present.
    if "import { FC } from 'react';" not in text:
        raise RuntimeError(
            "AvatarEditorSelectorView: expected FC import not found."
        )

    replacement = """import { FC } from 'react';
import { AvatarEditorUI2View } from './AvatarEditorUI2View';

/*
 * Project XeroX desktop wardrobe/editor.
 */
export const AvatarEditorView: FC<{}> = () =>
    <AvatarEditorUI2View />;
"""

    write(path, replacement)
else:
    print("ALREADY PATCHED: Xerox avatar editor selector")


# ------------------------------------------------------------
# icons.css — append Xerox video player icon if missing
# ------------------------------------------------------------

path = nitro / "src/css/icons/icons.css"
text = read(path)

icon_patch = read(package / "patches/video-player-icon.css").strip()

if ".octane-icon.icon-video-player" not in text:
    text = text.rstrip() + "\n\n" + icon_patch + "\n"
else:
    print("ALREADY PATCHED: video player icon")

write(path, text)


# ------------------------------------------------------------
# Final
# ------------------------------------------------------------

print()
print("=" * 70)

if args.dry_run:
    print(f"DRY RUN COMPLETE — {len(changed)} FILE(S) WOULD CHANGE")
    print("No destination files were modified.")
else:
    print(f"PATCH COMPLETE — {len(changed)} FILE(S) CHANGED")

print("=" * 70)

for path in changed:
    print(path.relative_to(nitro))
