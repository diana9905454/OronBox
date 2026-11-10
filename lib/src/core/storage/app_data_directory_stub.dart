import 'app_data_directory.dart';

Future<AppDataDirectory> openAppDataDirectory(
  String namespace,
  AppStorageLocation location,
) => Future.error(UnsupportedError('Application storage is unavailable'));
