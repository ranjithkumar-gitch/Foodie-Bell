import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../data/models/order.dart';
import '../../../shared/legal/legal_info.dart';
import '../../../shared/utils/date_text.dart';

/// A printable invoice for a delivered order (2026-11-20), for customers
/// who need one for their tax records. Built on the phone from the order
/// itself — the same lines and totals the order screen shows.
///
/// Noto Sans (plus Noto Sans Telugu for item names typed in Telugu) is
/// fetched by `printing` so ₹ and Telugu render; offline, it falls back to
/// the built-in font with "Rs." amounts.
Future<Uint8List> buildOrderInvoicePdf(Order order) async {
  pw.ThemeData? theme;
  try {
    theme = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.notoSansRegular(),
      bold: await PdfGoogleFonts.notoSansBold(),
      fontFallback: [await PdfGoogleFonts.notoSansTeluguRegular()],
    );
  } catch (_) {
    theme = null;
  }
  final rupee = theme == null ? 'Rs. ' : '₹';
  final num = NumberFormat('#,##,##0.00', 'en_IN');
  String money(double v) => '${v < 0 ? '-' : ''}$rupee${num.format(v.abs())}';

  final deliveredAt = order.statusReachedAt(OrderStatus.delivered);
  final address = order.deliveryAddressFull ?? order.deliveryAddressLabel;
  const muted = PdfColor.fromInt(0xFF6B7280);
  const line = PdfColor.fromInt(0xFFE5E7EB);
  const brand = PdfColor.fromInt(0xFF1B7A3E);

  pw.Widget label(String text) => pw.Text(text, style: const pw.TextStyle(fontSize: 9, color: muted));
  pw.Widget totalRow(String name, double value, {bool strong = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      children: [
        pw.Expanded(child: pw.Text(name, style: pw.TextStyle(fontSize: strong ? 12 : 10, fontWeight: strong ? pw.FontWeight.bold : null))),
        pw.Text(money(value), style: pw.TextStyle(fontSize: strong ? 12 : 10, fontWeight: strong ? pw.FontWeight.bold : null)),
      ],
    ),
  );

  final doc = pw.Document(title: 'Invoice ${order.id}', author: LegalInfo.app, theme: theme);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: muted)),
      ),
      build: (ctx) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(LegalInfo.app, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: brand)),
                  pw.SizedBox(height: 2),
                  pw.Text('Order invoice', style: const pw.TextStyle(fontSize: 11, color: muted)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                label('Order ID'),
                pw.Text(order.id, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                label('Order date'),
                pw.Text(dmy(order.placedAt), style: const pw.TextStyle(fontSize: 10)),
                if (deliveredAt != null) ...[
                  pw.SizedBox(height: 6),
                  label('Delivered on'),
                  pw.Text(dmy(deliveredAt), style: const pw.TextStyle(fontSize: 10)),
                ],
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  label('Sold by'),
                  pw.SizedBox(height: 2),
                  pw.Text(order.vendorName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  label('Billed to'),
                  pw.SizedBox(height: 2),
                  pw.Text(order.userName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  if (order.userPhone.isNotEmpty) pw.Text(order.userPhone, style: const pw.TextStyle(fontSize: 10)),
                  if (address.isNotEmpty) pw.Text(address, style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(
          headers: ['#', 'Item', 'Qty', 'Rate', 'Amount'],
          data: [
            for (var i = 0; i < order.items.length; i++)
              [
                '${i + 1}',
                order.items[i].name,
                '${order.items[i].quantity}',
                money(order.items[i].price),
                money(order.items[i].lineTotal),
              ],
          ],
          headerStyle: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: brand),
          cellStyle: const pw.TextStyle(fontSize: 9.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: line, width: 0.5)),
          columnWidths: {
            0: const pw.FixedColumnWidth(22),
            1: const pw.FlexColumnWidth(),
            2: const pw.FixedColumnWidth(36),
            3: const pw.FixedColumnWidth(72),
            4: const pw.FixedColumnWidth(80),
          },
          cellAlignments: {0: pw.Alignment.centerLeft, 2: pw.Alignment.center, 3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight},
          headerAlignments: {2: pw.Alignment.center, 3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight},
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          children: [
            pw.Spacer(),
            pw.SizedBox(
              width: 240,
              child: pw.Column(
                children: [
                  totalRow('Item total', order.subtotal),
                  if (order.couponCode != null) totalRow('Coupon (${order.couponCode})', -order.couponDiscount),
                  totalRow('Delivery fee', order.deliveryFee),
                  if (order.platformFee > 0) totalRow('Platform fee', order.platformFee),
                  if (order.legacyTaxCharged > 0) totalRow('Tax', order.legacyTaxCharged),
                  pw.Divider(color: line),
                  totalRow('Total paid', order.total, strong: true),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: line), borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Payment method: ${order.paymentMethod.label}', style: const pw.TextStyle(fontSize: 10)),
              if (order.paymentStatus != OrderPaymentStatus.unknown) pw.Text('Payment status: ${order.paymentLabel}', style: const pw.TextStyle(fontSize: 10)),
              if (order.paymentReference != null) pw.Text('Payment reference: ${order.paymentReference}', style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Text('Item prices are inclusive of applicable taxes.', style: const pw.TextStyle(fontSize: 9, color: muted)),
        pw.Text('This is a computer-generated invoice and needs no signature.', style: const pw.TextStyle(fontSize: 9, color: muted)),
      ],
    ),
  );
  return doc.save();
}

/// Opens the system print / save sheet for [order]'s invoice — "Save as
/// PDF" downloads it, or it can be printed or shared from there.
Future<void> downloadOrderInvoice(BuildContext context, Order order, {required String failedMessage}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Printing.layoutPdf(name: 'QuickMandi-invoice-${order.id}.pdf', onLayout: (_) => buildOrderInvoicePdf(order));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(failedMessage)));
  }
}
