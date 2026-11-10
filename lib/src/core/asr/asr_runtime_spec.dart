class AsrRuntimeFile {
  const AsrRuntimeFile(this.name, this.bytes, this.sha256);
  final String name;
  final int bytes;
  final String sha256;
}

class AsrRuntimeSpec {
  const AsrRuntimeSpec(
    this.package,
    this.abi,
    this.bytes,
    this.sha256,
    this.files,
  );
  static const version = '1.13.8';
  final String package, abi, sha256;
  final int bytes;
  final List<AsrRuntimeFile> files;
}

const androidAsrRuntimes = [
  AsrRuntimeSpec(
    'sherpa_onnx_android_arm64',
    'arm64-v8a',
    10474637,
    '29db5572735afb1bc29f0f95ab160f7fb38b4b3f926f48e9113457fd740264f4',
    [
      AsrRuntimeFile(
        'libonnxruntime.so',
        22249560,
        '33847ad43bffe204699fd4a27f7f3603452a8cdaf2f9a44983a0bc31ffcf2da1',
      ),
      AsrRuntimeFile(
        'libsherpa-onnx-c-api.so',
        4499112,
        '42308b0dd41ac79639330c58ac69dec9c3a6bc94c8b6ae96b0311963bc13f0b0',
      ),
    ],
  ),
  AsrRuntimeSpec(
    'sherpa_onnx_android_armeabi',
    'armeabi-v7a',
    9447445,
    'fe81837bd12f67d136a456c6d2b39876caaba09edd77761cb527cb170dac2d2a',
    [
      AsrRuntimeFile(
        'libonnxruntime.so',
        15359592,
        '7a8f17a707e52e0ac3a026be319272876d9eae61f4bb19585292772d785f7744',
      ),
      AsrRuntimeFile(
        'libsherpa-onnx-c-api.so',
        3202776,
        '66b2e4caa8abc40cd8b33d4856a5e494072b97f4dca4b69d81fdcc860feab03e',
      ),
    ],
  ),
  AsrRuntimeSpec(
    'sherpa_onnx_android_x86_64',
    'x86_64',
    11442128,
    'd20c06c0edc92286609f256d04c295cad510bbb270068c0c79877f4a10f00581',
    [
      AsrRuntimeFile(
        'libonnxruntime.so',
        25581120,
        '087e84297cad64acb823c3d901d6e0cc934e91add7cdb20da802cd1c0bea5c3e',
      ),
      AsrRuntimeFile(
        'libsherpa-onnx-c-api.so',
        5002888,
        'f3204723864da2d2ed43898e08baff0975472cc1d7412dcde77c5dc0b051d336',
      ),
    ],
  ),
];
