class XiaomiDeviceCapabilities {
  const XiaomiDeviceCapabilities({
    this.deviceCapability = 0,
    this.deviceCapabilityV2 = 0,
  });

  final int deviceCapability;
  final int deviceCapabilityV2;

  bool get supportsAivsLargeModel => (deviceCapabilityV2 & 256) != 0;
}
