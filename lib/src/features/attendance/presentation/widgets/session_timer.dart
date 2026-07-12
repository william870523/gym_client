import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SessionTimer extends StatefulWidget {
  final Duration sessionDuration;
  final Duration initialElapsed;
  final bool isPaused;
  final bool isOvertime; // Explicit flag or derived? Derived is safer.

  const SessionTimer({
    super.key,
    required this.sessionDuration,
    required this.initialElapsed,
    required this.isPaused,
    this.isOvertime = false,
  });

  @override
  State<SessionTimer> createState() => _SessionTimerState();
}

class _SessionTimerState extends State<SessionTimer> {
  late Duration _elapsed;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _elapsed = widget.initialElapsed;
    if (!widget.isPaused) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = _elapsed + const Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(SessionTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused != oldWidget.isPaused) {
      if (widget.isPaused) {
        _timer?.cancel();
      } else {
        _startTimer();
      }
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    // Calculate remaining
    // If duration < elapsed, we are overtime.
    final bool isExceeded = _elapsed > widget.sessionDuration;
    final Duration remaining = isExceeded
        ? _elapsed - widget.sessionDuration
        : widget.sessionDuration - _elapsed;

    final bool isWarning = !isExceeded && remaining.inMinutes < 10;

    // Styles
    Color bg = Colors.white; // Default for active container
    Color border = const Color(0xFFE2E8F0); // gray-200
    Color iconColor = const Color(0xFF135BEC); // primary
    Color textColor = const Color(0xFF0F172A); // slate-900
    IconData icon = Icons.timer;
    String statusText =
        "Restante de ${_formatDuration(widget.sessionDuration)}";
    Color statusTextColor = const Color(0xFF94A3B8); // slate-400
    bool animatePulse = false;

    if (widget.isPaused) {
      bg = const Color(0xFFF8FAFC); // slate-50
      border = const Color(0xFFE2E8F0);
      iconColor = const Color(0xFFEAB308); // yellow-500
      textColor = const Color(0xFF475569); // slate-600
      icon = Icons.pause_circle;
      // statusText remains same
    } else if (isExceeded) {
      // Overtime (Red)
      bg = Colors.white;
      border = const Color(0xFFFECACA); // red-200
      iconColor = const Color(0xFFDC2626); // red-600
      textColor = const Color(0xFFB91C1C); // red-700
      icon = Icons.alarm_off;
      statusText =
          "EXCEDIDO +${_formatDuration(remaining).substring(0, 5)}"; // Show HH:MM
      statusTextColor = const Color(0xFFEF4444); // red-500
    } else if (isWarning) {
      // Warning (Orange)
      bg = const Color(0xFFFFF7ED); // orange-50
      border = const Color(0xFFFED7AA); // orange-200
      iconColor = const Color(0xFFF97316); // orange-500
      textColor = const Color(0xFFC2410C); // orange-700
      icon = Icons.hourglass_bottom;
      statusText = "Finaliza pronto";
      statusTextColor = const Color(0xFFFB923C); // orange-400
      animatePulse = true;
    } else {
      // Normal Active (Blue/Green) - User HTML uses primary blue sometimes or slate
      // Let's stick to the HTML example for "Juan Perez":
      // bg-white border-gray-200 shadow-sm
      // icon primary animate-pulse
      animatePulse = true;
    }

    // Override text calculation for display
    final displayTime = isExceeded
        ? _formatDuration(remaining)
        : _formatDuration(remaining);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              _AnimatedIcon(
                icon: icon,
                color: iconColor,
                shouldPulse: animatePulse && !widget.isPaused,
              ),
              const SizedBox(width: 8),
              // Time
              Text(
                displayTime,
                style: GoogleFonts.robotoMono(
                  // Monospace for numbers
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            statusText,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: statusTextColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool shouldPulse;

  const _AnimatedIcon({
    required this.icon,
    required this.color,
    required this.shouldPulse,
  });

  @override
  State<_AnimatedIcon> createState() => _AnimatedIconState();
}

class _AnimatedIconState extends State<_AnimatedIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(
      begin: 1.0,
      end: 0.6,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.shouldPulse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AnimatedIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldPulse != oldWidget.shouldPulse) {
      if (widget.shouldPulse) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0; // Reset
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.shouldPulse) {
      return Icon(widget.icon, color: widget.color, size: 18);
    }
    return FadeTransition(
      opacity: _animation,
      child: Icon(widget.icon, color: widget.color, size: 18),
    );
  }
}
