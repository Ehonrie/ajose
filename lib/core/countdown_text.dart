import 'dart:async';

import 'package:flutter/material.dart';

import 'date_formatting.dart';

/// A [Text] showing [formatCountdown] against [deadline], ticking every
/// second so a near deadline (the 10-minute test cadence especially)
/// visibly counts down instead of showing a stale snapshot from whenever
/// the enclosing screen last rebuilt.
class CountdownText extends StatefulWidget {
  const CountdownText(this.deadline, {super.key, this.style});

  final DateTime deadline;
  final TextStyle? style;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(formatCountdown(widget.deadline), style: widget.style);
  }
}
