import 'package:oronbox/src/core/storage/app_data_directory.dart';

import 'asr.dart';
import 'asr_model_store.dart';

Future<AsrEngine> openLocalAsr(AsrModelStore model) =>
    Future.error(const AsrFailure('unsupported'));

Future<bool> modelUsedByCurrentProcess(AppDataDirectory directory) async =>
    false;
