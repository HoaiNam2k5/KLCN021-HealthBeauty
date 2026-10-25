import 'package:flutter/foundation.dart';

class InvoiceNotificationTarget {
  const InvoiceNotificationTarget({this.invoiceId, this.appointmentId});
  final int? invoiceId;
  final int? appointmentId;

  static InvoiceNotificationTarget? fromPayload(Map<String, dynamic> data) {
    final type = data['type']?.toString().toUpperCase();
    if (type != 'INVOICE' && type != 'HOADON') return null;
    int? positive(Object? value) {
      final id = int.tryParse(value?.toString() ?? '');
      return id != null && id > 0 ? id : null;
    }

    return InvoiceNotificationTarget(
      invoiceId: positive(data['invoiceId']),
      appointmentId: positive(data['appointmentId']),
    );
  }
}

// Keeps notification intents received before login/MaterialApp initialization.
final invoiceNotificationTarget = ValueNotifier<InvoiceNotificationTarget?>(
  null,
);
