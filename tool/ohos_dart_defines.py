#!/usr/bin/env python3
"""Emit the DART_DEFINES payload the ohos hvigor plugin expects.

`flutter build hap` normally serialises `--dart-define` values into the
`DART_DEFINES` parameter: every `key=value` entry is base64-encoded and the
entries are joined with commas (see `encodeDartDefines` in
flutter_tools/lib/src/build_info.dart). When the OpenHarmony app is assembled
by calling hvigor directly we have to build that blob ourselves.

The attestation values come from `build/integrity_defines.json`, which
`tool/prepare_build_integrity.py` writes from the per-build derived key. This
helper never reads the master key and never prints the blob, so the derived
key does not leak into build logs.
"""
import argparse
import base64
import json
from pathlib import Path

# Order is stable so repeated builds produce the same payload.
DEFINE_ORDER = ("APP_VERSION", "OB_AUTH_TAG", "OB_AUTH_COMMIT", "OB_RELEASE_KEY")


def encode_entry(value):
    return base64.b64encode(value.encode("utf-8")).decode("ascii")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True, help="build name, e.g. 1.2.0")
    parser.add_argument(
        "--defines",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "build/integrity_defines.json",
        help="attestation defines written by prepare_build_integrity.py",
    )
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument(
        "--dart-out",
        type=Path,
        default=None,
        help="write the same values as Dart constants for the attested client",
    )
    args = parser.parse_args()

    values = {"APP_VERSION": args.version}
    if args.defines.is_file():
        values.update(json.loads(args.defines.read_text(encoding="utf-8")))
    else:
        # Missing attestation is allowed (the client then skips signing and the
        # server answers 401); surface it once instead of failing the build.
        print("warning: %s not found, building without client attestation" % args.defines)

    entries = [
        "%s=%s" % (name, values[name]) for name in DEFINE_ORDER if name in values
    ]
    blob = ",".join(encode_entry(entry) for entry in entries)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    # Trailing newline: the build script consumes this with `set /p`, which
    # yields an empty value when the file ends without a line break.
    args.out.write_text(blob + "\n", encoding="ascii")
    print("wrote %s (%d defines)" % (args.out, len(entries)))

    if args.dart_out is not None:
        write_dart_constants(args.dart_out, values)
        print("wrote %s" % args.dart_out)


DART_TEMPLATE = """// GENERATED FILE - DO NOT EDIT, DO NOT COMMIT.
//
// Written by tool/ohos_dart_defines.py from build/integrity_defines.json.
// The hvigor plugin forwards DART_DEFINES to `flutter assemble`, but the
// OpenHarmony kernel target never sees those values, so the client reads the
// per-build attestation identity from these constants instead. The values are
// intentionally empty when the build has no attestation key.
const String kBuildAttestationTag = '{tag}';
const String kBuildAttestationCommit = '{commit}';
const String kBuildAttestationReleaseKey = '{key}';
"""


def write_dart_constants(path, values):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        DART_TEMPLATE.format(
            tag=values.get("OB_AUTH_TAG", ""),
            commit=values.get("OB_AUTH_COMMIT", ""),
            key=values.get("OB_RELEASE_KEY", ""),
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
