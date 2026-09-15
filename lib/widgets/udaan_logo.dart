import 'package:flutter/material.dart';

class UdaanLogo extends StatelessWidget {
  const UdaanLogo({
    super.key,
    this.size = 64,
    this.showName = false,
    this.light = false,
  });

  final double size;
  final bool showName;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final label = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UDAAN',
          style: TextStyle(
            color: light ? Colors.white : const Color(0xFF123B73),
            fontSize: size * 0.28,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        Text(
          'EDU ERP',
          style: TextStyle(
            color: light ? Colors.white70 : const Color(0xFF0EA5A8),
            fontSize: size * 0.14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0EA5A8), Color(0xFF123B73)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF123B73).withValues(alpha: 0.22),
                blurRadius: size * 0.18,
                offset: Offset(0, size * 0.08),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: size * 0.48),
              Positioned(
                bottom: size * 0.14,
                child: Container(
                  width: size * 0.5,
                  height: size * 0.07,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(size),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showName) ...[
          SizedBox(width: size * 0.18),
          label,
        ],
      ],
    );
  }
}
