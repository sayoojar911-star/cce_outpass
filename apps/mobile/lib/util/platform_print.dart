import 'package:flutter/foundation.dart';
import 'platform_print_stub.dart'
    if (dart.library.html) 'platform_print_web.dart' as impl;

void triggerPrint() {
  if (kIsWeb) {
    impl.printTicketWeb();
  }
}
