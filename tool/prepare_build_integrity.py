#!/usr/bin/env python3
"""Prepare per-build Dart defines shared by Bash, PowerShell and release CI."""
import argparse
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import tempfile


def valid_config(value, version, commit):
    return (
        isinstance(value, dict)
        and value.get("OB_AUTH_TAG") == version
        and value.get("OB_AUTH_COMMIT") == commit
        and isinstance(value.get("OB_RELEASE_KEY"), str)
        and re.fullmatch(r"[a-fA-F0-9]{64}", value["OB_RELEASE_KEY"])
    )


def write_config(path, config):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".integrity-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as output:
            json.dump(config, output, indent=2)
            output.write("\n")
        os.chmod(name, 0o600)
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def prepare(root, version, commit):
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?", version):
        raise ValueError("Invalid build version")
    if not re.fullmatch(r"[0-9a-fA-F]{40}|[0-9a-fA-F]{64}", commit):
        raise ValueError("Expected the full Git commit")
    build = root / "build/integrity_defines.json"
    saved = root / "config/integrity_defines.local.json"
    master = os.environ.get("ORONBOX_AUTH_MASTER", "")
    release_key = os.environ.get("OB_RELEASE_KEY", "")
    config = None
    if master or release_key:
        source = master or release_key
        if not re.fullmatch(r"[a-fA-F0-9]{64}", source):
            raise ValueError("Attestation key must contain exactly 64 hexadecimal characters")
        key = bytes.fromhex(source)
        if master:
            key = hmac.digest(key, f"oronbox:v1:{version}:{commit}".encode(), "sha256")
        config = dict(OB_AUTH_TAG=version, OB_AUTH_COMMIT=commit, OB_RELEASE_KEY=key.hex())
    else:
        for path in (build, saved):
            try:
                value = json.loads(path.read_text(encoding="utf-8"))
                if valid_config(value, version, commit):
                    config = value
                    break
            except (ValueError, OSError):
                continue
    if config is None:
        raise ValueError(
            "Set ORONBOX_AUTH_MASTER or OB_RELEASE_KEY, or provide matching "
            "config/integrity_defines.local.json for this version and commit"
        )
    if os.environ.get("GITHUB_ACTIONS") == "true":
        print("::add-mask::" + config["OB_RELEASE_KEY"], flush=True)
    write_config(build, config)
    write_config(saved, config)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    try:
        prepare(args.project_root, args.version, args.commit)
    except (ValueError, OSError) as error:
        parser.exit(1, f"Build attestation configuration failed: {error}\n")


if __name__ == "__main__":
    main()
