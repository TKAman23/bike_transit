import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:bike_transit/models/route_option.dart';
import 'package:bike_transit/models/user_preferences.dart';
import 'package:bike_transit/utils/format.dart';

/// Route number in a rounded box colored like its map line.
class TransitBadge extends StatelessWidget {
  const TransitBadge({super.key, required this.section, this.large = false});

  final RouteSection section;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = section.transit!;
    final onColor =
        section.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 10 : 7, vertical: large ? 6 : 3),
      decoration: BoxDecoration(
        color: section.color,
        borderRadius: BorderRadius.circular(large ? 10 : 7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(t.isRail ? Icons.tram : Icons.directions_bus,
              size: large ? 16 : 13, color: onColor),
          const SizedBox(width: 3),
          Text(
            t.routeShortName,
            style: TextStyle(
              color: onColor,
              fontWeight: FontWeight.w700,
              fontSize: large ? 15 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Every section of a route, left to right (CARD-4).
class SectionStrip extends StatelessWidget {
  const SectionStrip({super.key, required this.route, required this.units});

  final RouteOption route;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final distanceStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: muted, fontWeight: FontWeight.w500);
    final children = <Widget>[];
    for (var i = 0; i < route.sections.length; i++) {
      final s = route.sections[i];
      if (i > 0) children.add(_Connector(color: s.color));
      children.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          switch (s.type) {
            SectionType.bike =>
              Icon(Icons.directions_bike, size: 18, color: s.color),
            SectionType.walk =>
              Icon(Icons.directions_walk, size: 18, color: s.color),
            SectionType.transit => TransitBadge(section: s),
          },
          const SizedBox(width: 4),
          Text(Fmt.distance(s.distanceM, units), style: distanceStyle),
        ],
      ));
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 6,
      children: children,
    );
  }
}

/// Dot · colored line · dot separator between sections.
class _Connector extends StatelessWidget {
  const _Connector({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline,
        shape: BoxShape.circle,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        Container(
          width: 12,
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        dot,
      ],
    );
  }
}

/// Minimal outline of the elevation profile (CARD-7).
class TerrainGraph extends StatelessWidget {
  const TerrainGraph({super.key, required this.profile, required this.color});

  final ElevationProfile profile;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < profile.distancesM.length; i++)
        FlSpot(profile.distancesM[i], profile.elevationsM[i]),
    ];
    final pad = ((profile.maxM - profile.minM) * 0.15).clamp(2.0, 50.0);
    return LineChart(
      LineChartData(
        minY: profile.minM - pad,
        maxY: profile.maxM + pad,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 1.6,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
      duration: Duration.zero,
    );
  }
}

/// Minimalist mountain-outline icon (CARD-7).
class MountainOutlineIcon extends StatelessWidget {
  const MountainOutlineIcon({super.key, this.size = 26, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.8),
      painter: _MountainPainter(
          color ?? Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

class _MountainPainter extends CustomPainter {
  _MountainPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, h)
      ..lineTo(w * 0.38, h * 0.15)
      ..lineTo(w * 0.58, h * 0.55)
      ..lineTo(w * 0.72, h * 0.35)
      ..lineTo(w, h);
    canvas.drawPath(path, paint);
    final snow = Path()
      ..moveTo(w * 0.27, h * 0.4)
      ..lineTo(w * 0.36, h * 0.48)
      ..lineTo(w * 0.44, h * 0.4);
    canvas.drawPath(snow, paint..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_MountainPainter old) => old.color != color;
}
