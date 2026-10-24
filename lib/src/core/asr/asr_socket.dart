export 'asr_socket_stub.dart'
    if (dart.library.io) 'asr_socket_io.dart'
    if (dart.library.js_interop) 'asr_socket_web.dart';
