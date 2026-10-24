import 'storage_capacity_stub.dart'
    if (dart.library.io) 'storage_capacity_io.dart'
    if (dart.library.js_interop) 'storage_capacity_web.dart'
    as platform;

/// Null means that the platform did not provide an estimate.
Future<int?> availableStorageBytes() => platform.availableStorageBytes();
