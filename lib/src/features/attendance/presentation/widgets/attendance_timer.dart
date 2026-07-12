import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/time/app_clock.dart';
import 'package:google_fonts/google_fonts.dart';

class AttendanceTimer extends StatefulWidget {
  final DateTime checkInTime;
  final bool isPausedInitial;

  const AttendanceTimer({
    super.key,
    required this.checkInTime,
    this.isPausedInitial = false,
  });

  @override
  State<AttendanceTimer> createState() => _AttendanceTimerState();
}

class _AttendanceTimerState extends State<AttendanceTimer> {
  late Timer _timer;
  late Duration _elapsed;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _isPaused = widget.isPausedInitial;
    _updateElapsed();
    _startTimer();
  }

  void _updateElapsed() {
    if (!_isPaused) {
      _elapsed = appClock.nowUtc().difference(widget.checkInTime.toUtc());
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _updateElapsed();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
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
    // Logic for exceeded time (60 min default)
    final exceeded = _elapsed.inMinutes >= 60;
    final remainingMsg = exceeded
        ? 'EXCEDIDO +${_formatDuration(_elapsed - const Duration(hours: 1))}'
        : 'Restante de 1:00:00'; // Hardcoded base for now

    // Colors based on state
    final Color bg = exceeded
        ? const Color(0xFFFEF2F2)
        : Colors.white; // Red-50 vs White
    final Color border = exceeded
        ? const Color(0xFFFECACA)
        : const Color(0xFFE2E8F0); // Red-200 vs Slate-200
    final Color textMain = exceeded
        ? const Color(0xFFDC2626)
        : const Color(0xFF334155); // Red-600 vs Slate-700
    final Color textSub = exceeded
        ? const Color(0xFFEF4444)
        : const Color(0xFF94A3B8); // Red-500 vs Slate-400
    final IconData statusIcon = exceeded
        ? Icons.timer_off_outlined
        : Icons.timer_outlined;

    // Pause Button Styles
    final Color pauseBtnBg = _isPaused
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEF9C3); // Green-100 (Resume) vs Yellow-100 (Pause)
    final Color pauseBtnIconColor = _isPaused
        ? const Color(0xFF22C55E)
        : const Color(0xFFEAB308); // Green-500 vs Yellow-500
    final IconData pauseBtnIcon = _isPaused
        ? Icons.play_arrow_rounded
        : Icons.pause_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Timer Box
        Container(
          height: 56, // Fixed height for consistency
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (!exceeded)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 16, color: textMain),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(_elapsed),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                      letterSpacing: 0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                remainingMsg,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textSub,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Pause/Play Button (Circular)
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pauseBtnBg.withValues(alpha: 0.3),
            border: Border.all(color: pauseBtnBg),
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _togglePause,
              customBorder: const CircleBorder(),
              child: Icon(pauseBtnIcon, size: 20, color: pauseBtnIconColor),
            ),
          ),
        ),
      ],
    );
  }
}
