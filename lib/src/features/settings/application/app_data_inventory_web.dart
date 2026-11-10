import 'package:oronbox/src/features/plugins/storage/plugin_storage.dart';
import 'package:oronbox/src/features/plugins/storage/plugin_storage_web.dart';

import 'app_data_inventory.dart';

Future<Map<AppDataCategory, int>> collectFileUsage() async {
  final usage = await collectWebPluginStorageUsage();
  return {
    AppDataCategory.plugins:
        (usage[PluginStorageArea.package] ?? 0) +
        (usage[PluginStorageArea.data] ?? 0),
    AppDataCategory.cache: usage[PluginStorageArea.cache] ?? 0,
    AppDataCategory.downloads: usage[PluginStorageArea.temporary] ?? 0,
  };
}
