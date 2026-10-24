import 'package:disk_usage/disk_usage.dart';
import 'package:path_provider/path_provider.dart';

Future<int?> availableStorageBytes() async {
  try {
    return await DiskUsage.freeSpace(
      (await getApplicationSupportDirectory()).path,
    );
  } catch (_) {
    return null;
  }
}
