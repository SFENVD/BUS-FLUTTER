import 'demo_persistence.dart';
import 'demo_persistence_stub.dart'
    if (dart.library.js_interop) 'demo_persistence_web.dart'
    as platform;

DemoPersistence createDemoPersistence() => platform.createDemoPersistence();
