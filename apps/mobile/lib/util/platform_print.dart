import 'package:flutter/foundation.dart';
import 'platform_print_stub.dart'
    if (dart.library.js_interop) 'platform_print_web.dart' as impl;

void triggerPrint({String? html}) {
  if (kIsWeb) {
    impl.printTicketWeb(html: html);
  }
}
