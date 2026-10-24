export 'health_database_connection_stub.dart'
    if (dart.library.io) 'health_database_connection_io.dart'
    if (dart.library.js_interop) 'health_database_connection_web.dart';
