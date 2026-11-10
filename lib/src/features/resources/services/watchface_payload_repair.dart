/// Creator-side repair helpers for malformed Vela watchface payloads.
///
/// These belong to the resource pipeline, not device install policy: the
/// repaired bytes are uploaded as an artifact and may never be installed by
/// OronBox itself.
bool isZeroVelaWatchfaceId(List<int> bytes) {
  const idOffset = 0x28;
  const idLength = 12;
  if (bytes.length < idOffset + idLength) return false;
  final raw = bytes.sublist(idOffset, idOffset + idLength);
  return raw.every((byte) => byte == 0 || byte == 0x30);
}

/// Overwrites the 12-byte id field of a Vela watchface payload.
///
/// Returns null when the payload is shorter than the id field: the caller
/// must abort, because uploading unpatched bytes while stamping a new
/// identifier would make the metadata diverge from the binary.
List<int>? replaceVelaWatchfaceId(List<int> bytes, String id) {
  const idOffset = 0x28;
  const idLength = 12;
  if (bytes.length < idOffset + idLength) return null;
  final result = [...bytes];
  for (var i = 0; i < idLength; i++) {
    result[idOffset + i] = i < id.length ? id.codeUnitAt(i) : 0;
  }
  return result;
}
