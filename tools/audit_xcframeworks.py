#!/usr/bin/env python3
"""Check packaged media frameworks before uploading CI artifacts."""
import re
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path


def run(*args):
    return subprocess.check_output(args, text=True)


def audit(archive):
    errors = []
    count = 0
    with tempfile.TemporaryDirectory(prefix="libmpv-audit-") as work:
        with tarfile.open(archive) as bundle:
            for item in bundle.getmembers():
                if item.name.startswith("/") or ".." in Path(item.name).parts:
                    raise ValueError(f"Unsafe archive path: {item.name}")
            bundle.extractall(work)
        root = next(Path(work).iterdir())
        if not (root / "Placebo.xcframework").is_dir():
            errors.append("Missing Placebo.xcframework")
        for framework in root.glob("*.xcframework/*/*.framework"):
            binary = framework / framework.stem
            if not binary.is_file():
                errors.append(f"Missing framework executable: {binary}")
                continue
            count += 1
            slice_root = framework.parent
            imports = run("xcrun", "dyld_info", "-imports", str(binary))
            for symbol, library in re.findall(r"^\s+(\S+)\s+\(from ([^)]+)\)", imports, re.M):
                if library in ("libswiftCoreMedia", "SwiftCoreMedia") and re.match(r"^_(CM|kCM)", symbol):
                    errors.append(f"{framework.name}: {symbol} bound to {library}")
                if library == "<flat-namespace>":
                    errors.append(f"{framework.name}: unresolved {symbol}")
            commands = run("otool", "-l", str(binary))
            for block in commands.split("Load command ")[1:]:
                cmd = re.search(r"^\s+cmd (\S+)", block, re.M)
                if not cmd or cmd[1] not in ("LC_LOAD_DYLIB", "LC_REEXPORT_DYLIB", "LC_LOAD_UPWARD_DYLIB"):
                    continue
                name = re.search(r"^\s+name (.*?) \(offset", block, re.M)
                if not name:
                    continue
                dep = name[1]
                if dep.startswith("/nix/store/"):
                    errors.append(f"{framework.name}: build-machine dependency {dep}")
                if dep.startswith("@rpath/") and ".framework/" in dep:
                    sibling_name = dep[len("@rpath/"):].split("/", 1)[0]
                    sibling = root / sibling_name.replace(".framework", ".xcframework") / slice_root.name / dep[len("@rpath/"):]
                    if not sibling.is_file():
                        errors.append(f"{framework.name} [{slice_root.name}]: missing {dep}")
        if not count:
            errors.append("Archive contains no framework slices")
    if errors:
        raise RuntimeError("\n".join(errors))
    print(f"PASS {archive}: {count} framework slices; Placebo and required dependencies present")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("Usage: audit_xcframeworks.py archive.tar.gz [...]")
    for archive in sys.argv[1:]:
        audit(archive)
