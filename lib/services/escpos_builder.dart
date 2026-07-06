import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../models/receipt.dart';

/// Builds ESC/POS byte streams for a [Receipt] sized for 58mm or 80mm paper.
///
/// Layout is tuned for readability on narrow paper: a bold, double-size
/// business name and grand total; everything else at normal size with clear
/// separators. Long item names print on their own full-width line and wrap
/// naturally, with qty/price on the left and the line total on the right.
class EscPosBuilder {
  EscPosBuilder._();

  static Future<List<int>> build(Receipt r, PaperSize size) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(size, profile);
    final List<int> b = [];

    b.addAll(g.reset());

    // ---- Header ----
    if (r.businessName.isNotEmpty) {
      b.addAll(g.text(
        r.businessName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ));
    }
    if (r.receiptTitle.isNotEmpty) {
      b.addAll(g.text(r.receiptTitle,
          styles: const PosStyles(align: PosAlign.center, bold: true)));
    }
    for (final line in <String>[
      r.branch,
      r.city,
      if (r.phone.isNotEmpty) 'Tel: ${r.phone}',
      if (r.email.isNotEmpty) r.email,
      if (r.pin.isNotEmpty) 'PIN: ${r.pin}',
    ]) {
      if (line.trim().isNotEmpty) {
        b.addAll(g.text(line, styles: const PosStyles(align: PosAlign.center)));
      }
    }

    b.addAll(g.hr());

    // ---- Meta ----
    if (r.invoiceNo.isNotEmpty) b.addAll(g.text('Invoice: ${r.invoiceNo}'));
    if (r.customer.isNotEmpty) b.addAll(g.text('Customer: ${r.customer}'));
    if (r.date.isNotEmpty) b.addAll(g.text('Date: ${r.date}'));

    b.addAll(g.hr());

    // ---- Items ----
    for (final it in r.items) {
      b.addAll(g.text(it.name, styles: const PosStyles(bold: true)));
      b.addAll(g.row([
        PosColumn(text: '${_qty(it.qty)} x ${_money(it.price)}', width: 7),
        PosColumn(
          text: _money(it.total),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }

    b.addAll(g.hr());

    // ---- Totals ----
    b.addAll(_totalRow(g, 'Subtotal', r.subtotal));
    if (r.discount != 0) b.addAll(_totalRow(g, 'Discount', r.discount));
    if (r.vat != 0) b.addAll(_totalRow(g, 'VAT', r.vat));

    b.addAll(g.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
      PosColumn(
        text: _money(r.total),
        width: 6,
        styles: const PosStyles(
          bold: true,
          align: PosAlign.right,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    ]));

    b.addAll(g.hr());

    // ---- Payment ----
    if (r.paymentMethod.isNotEmpty) b.addAll(g.text('Paid by: ${r.paymentMethod}'));
    if (r.paid != 0) b.addAll(_totalRow(g, 'Paid', r.paid));
    if (r.change != 0) b.addAll(_totalRow(g, 'Change', r.change));

    // ---- QR ----
    if (r.qrData.isNotEmpty) {
      b.addAll(g.feed(1));
      b.addAll(g.qrcode(r.qrData));
    }

    // ---- Footer ----
    if (r.footer.isNotEmpty) {
      b.addAll(g.feed(1));
      b.addAll(g.text(r.footer, styles: const PosStyles(align: PosAlign.center)));
    }

    b.addAll(g.feed(2));
    b.addAll(g.cut());
    return b;
  }

  /// A simple self-check receipt for the Test Print button.
  static Future<List<int>> buildTest(PaperSize size) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(size, profile);
    final List<int> b = [];
    b.addAll(g.reset());
    b.addAll(g.text('UpeoRetail Print',
        styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2)));
    b.addAll(g.text('Test print OK', styles: const PosStyles(align: PosAlign.center)));
    b.addAll(g.hr());
    b.addAll(g.row([
      PosColumn(text: 'Sample item', width: 8),
      PosColumn(text: '100.00', width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]));
    b.addAll(g.hr());
    b.addAll(g.qrcode('UPEORETAIL-TEST'));
    b.addAll(g.feed(2));
    b.addAll(g.cut());
    return b;
  }

  static List<int> _totalRow(Generator g, String label, double value) => g.row([
        PosColumn(text: label, width: 6),
        PosColumn(
          text: _money(value),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

  /// Money with thousands separators and 2 decimals (no currency symbol so it
  /// fits narrow paper; the business name/footer convey the currency context).
  static String _money(double v) {
    final neg = v < 0;
    final s = v.abs().toStringAsFixed(2);
    final parts = s.split('.');
    final digits = parts[0];
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return '${neg ? '-' : ''}$buf.${parts[1]}';
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);
}
