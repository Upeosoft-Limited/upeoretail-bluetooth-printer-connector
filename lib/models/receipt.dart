// Receipt data model parsed from the JavaScript bridge payload.
//
// Parsing is defensive: numbers may arrive as int, double or numeric string;
// missing fields fall back to sensible empty/zero values. validate() enforces
// the minimum required to print a meaningful receipt.

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '')) ?? 0;
}

String _toStr(dynamic v) => v == null ? '' : v.toString();

class ReceiptItem {
  final String name;
  final double qty;
  final double price;
  final double total;
  final double tax;

  const ReceiptItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.total,
    required this.tax,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> j) => ReceiptItem(
        name: _toStr(j['name']),
        qty: _toDouble(j['qty']),
        price: _toDouble(j['price']),
        total: _toDouble(j['total']),
        tax: _toDouble(j['tax']),
      );
}

class Receipt {
  final String businessName;
  final String receiptTitle;
  final String branch;
  final String city;
  final String phone;
  final String email;
  final String pin;
  final String invoiceNo;
  final String customer;
  final String date;
  final List<ReceiptItem> items;
  final double subtotal;
  final double discount;
  final double vat;
  final double total;
  final double paid;
  final double change;
  final String paymentMethod;
  final String footer;
  final String qrData;

  const Receipt({
    required this.businessName,
    required this.receiptTitle,
    required this.branch,
    required this.city,
    required this.phone,
    required this.email,
    required this.pin,
    required this.invoiceNo,
    required this.customer,
    required this.date,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.vat,
    required this.total,
    required this.paid,
    required this.change,
    required this.paymentMethod,
    required this.footer,
    required this.qrData,
  });

  factory Receipt.fromJson(Map<String, dynamic> j) {
    final rawItems = (j['items'] as List?) ?? const [];
    return Receipt(
      businessName: _toStr(j['businessName']),
      receiptTitle: _toStr(j['receiptTitle']).isEmpty ? 'RECEIPT' : _toStr(j['receiptTitle']),
      branch: _toStr(j['branch']),
      city: _toStr(j['city']),
      phone: _toStr(j['phone']),
      email: _toStr(j['email']),
      pin: _toStr(j['pin']),
      invoiceNo: _toStr(j['invoiceNo']),
      customer: _toStr(j['customer']),
      date: _toStr(j['date']),
      items: rawItems
          .whereType<Map>()
          .map((e) => ReceiptItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      subtotal: _toDouble(j['subtotal']),
      discount: _toDouble(j['discount']),
      vat: _toDouble(j['vat']),
      total: _toDouble(j['total']),
      paid: _toDouble(j['paid']),
      change: _toDouble(j['change']),
      paymentMethod: _toStr(j['paymentMethod']),
      footer: _toStr(j['footer']),
      qrData: _toStr(j['qrData']),
    );
  }

  /// Returns an error message if the receipt can't be printed, else null.
  String? validate() {
    if (items.isEmpty) return 'Receipt has no items.';
    if (businessName.isEmpty && invoiceNo.isEmpty) {
      return 'Receipt is missing a business name and invoice number.';
    }
    return null;
  }
}
