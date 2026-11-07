import 'dart:js_interop';

@JS('window.printCleanTicket')
external void _printCleanTicket(JSString html);

@JS('window.print')
external void _windowPrint();

void printTicketWeb({String? html}) {
  if (html != null && html.isNotEmpty) {
    try {
      _printCleanTicket(html.toJS);
      return;
    } catch (_) {}
  }
  _windowPrint();
}
