import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The one ₹-formatting entry point — replaces hand-rolled `$`/`₹` string
/// interpolation so every role's screens format money the same way.
class AppFormat {
  AppFormat._();

  static final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  static String currency(num value) => _currency.format(value);
}

class CurrencyText extends StatelessWidget {
  const CurrencyText(this.value, {super.key, this.style});

  final num value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(AppFormat.currency(value), style: style);
}
