import 'dart:async';

import 'package:flutter/material.dart';

/// "Just now" / "5 min ago" / "2 hr ago" / "3 days ago" / "2 months ago" /
/// "1 year ago" — how long ago [at] was, the one relative-time format the
/// whole app uses (notifications, order-status times, reviews, …). Each
/// unit rolls over to the next once it's full: 60 min → 1 hr, 24 hr → 1 day,
/// 30 days → 1 month, 12 months → 1 year. A time in the future (device
/// clock skew) reads as "Just now".
String timeAgo(DateTime at, {DateTime? now, bool telugu = false}) {
  final diff = (now ?? DateTime.now()).difference(at);
  final minutes = diff.inMinutes;
  final hours = diff.inHours;
  final days = diff.inDays;
  if (minutes < 1) return telugu ? 'ఇప్పుడే' : 'Just now';
  if (minutes < 60) return telugu ? '$minutes నిమి. క్రితం' : '$minutes min ago';
  if (hours < 24) return telugu ? '$hours గం. క్రితం' : '$hours hr ago';
  if (days < 30) {
    return telugu ? '$days ${days == 1 ? 'రోజు' : 'రోజుల'} క్రితం' : '$days ${days == 1 ? 'day' : 'days'} ago';
  }
  if (days < 365) {
    final months = days ~/ 30;
    return telugu ? '$months ${months == 1 ? 'నెల' : 'నెలల'} క్రితం' : '$months ${months == 1 ? 'month' : 'months'} ago';
  }
  final years = days ~/ 365;
  return telugu ? '$years సం. క్రితం' : '$years ${years == 1 ? 'year' : 'years'} ago';
}

/// [timeAgo] in the app's current language (Telugu when the User picked it).
String timeAgoOf(BuildContext context, DateTime at) =>
    timeAgo(at, telugu: Localizations.maybeLocaleOf(context)?.languageCode == 'te');

/// [timeAgoOf] as a Text that keeps itself current — re-renders every
/// minute, so "Just now" becomes "1 min ago" and so on while the screen
/// stays open, without its parent having to rebuild.
class TimeAgoText extends StatefulWidget {
  const TimeAgoText(this.at, {super.key, this.style});

  final DateTime at;
  final TextStyle? style;

  @override
  State<TimeAgoText> createState() => _TimeAgoTextState();
}

class _TimeAgoTextState extends State<TimeAgoText> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(timeAgoOf(context, widget.at), style: widget.style);
}
