"""Check the addon manifest before publishing. Requires only Python 3.9+."""

import argparse
import os
from pathlib import Path, PurePosixPath
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
VERSION_PATTERN = r"(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-(?:alpha|beta)\.[1-9]\d*)?"


def validate(root, tag=None):
    toc = (root / "Draxtilities.toc").read_text(encoding="utf-8-sig")
    metadata = dict(re.findall(r"^##\s*([^:]+):\s*(.*?)\s*$", toc, re.MULTILINE))
    version = metadata.get("Version", "")
    if not re.fullmatch(VERSION_PATTERN, version):
        raise ValueError("TOC Version must be X.Y.Z, optionally with -alpha.N or -beta.N")
    if tag and tag != f"v{version}":
        raise ValueError(f"Tag {tag!r} does not match TOC Version {version!r}; expected v{version}")

    if metadata.get("Dependencies") != "EllesmereUI":
        raise ValueError("The required EllesmereUI dependency is missing")
    interfaces = [value.strip() for value in metadata.get("Interface", "").split(",")]
    if not all(re.fullmatch(r"\d{6}", value) and int(value) >= 100000 for value in interfaces):
        raise ValueError("Interface must list Retail interface numbers")

    files = []
    for line in toc.splitlines():
        entry = line.strip()
        if not entry or entry.startswith("#"):
            continue
        path = PurePosixPath(entry.replace("\\", "/"))
        if path.is_absolute() or ".." in path.parts or ":" in entry:
            raise ValueError(f"TOC path must stay inside the addon: {entry}")
        current = root
        for part in path.parts:
            if part not in {child.name for child in current.iterdir()}:
                raise ValueError(f"Missing TOC path or incorrect filename case: {entry}")
            current = current / part
        if not current.is_file() or not current.resolve().is_relative_to(root.resolve()):
            raise ValueError(f"Invalid TOC file: {entry}")
        files.append(path.as_posix())
    if not files or len(files) != len(set(files)):
        raise ValueError("TOC file list is empty or contains duplicate entries")

    changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
    latest = re.search(r"^##\s+(\S+)", changelog, re.MULTILINE)
    if not latest or latest.group(1) != version:
        raise ValueError(f"The first CHANGELOG.md version must be {version}")
    for filename in ("README.md", "LICENSE", ".pkgmeta"):
        if not (root / filename).is_file():
            raise ValueError(f"Missing release file: {filename}")

    print(f"Validated Draxtilities {version}: {len(files)} runtime files, Retail {', '.join(interfaces)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", default=os.environ.get("RELEASE_TAG"), help="Expected release tag, e.g. v0.1.1")
    args = parser.parse_args()
    try:
        validate(ROOT, args.tag)
    except (OSError, ValueError) as error:
        print(f"Release validation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
