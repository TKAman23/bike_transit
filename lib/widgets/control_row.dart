import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:bike_transit/state/map_screen_controller.dart';

/// Location button cycle (Q1): centered → heading-up → north-up centered.
enum LocationMode { free, centered, headingUp }

const double controlRowHeight = 50;

/// Top row of the sheet: Route/Options switch + location + compass (SHEET-6…11).
class ControlRow extends StatelessWidget {
  const ControlRow({
    super.key,
    required this.segment,
    required this.onSegment,
    required this.locationMode,
    required this.onLocation,
    required this.bearing,
    required this.onCompass,
  });

  final SheetSegment segment;
  final ValueChanged<SheetSegment> onSegment;
  final LocationMode locationMode;
  final VoidCallback onLocation;
  final double bearing;
  final VoidCallback onCompass;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final buttonStyle = ElevatedButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: const Size.fromHeight(controlRowHeight),
    );
    return SizedBox(
      height: controlRowHeight,
      child: Row(
        children: [
          const SizedBox(width: 10),
          // Left half of the screen: 10 px from the edge to the midline.
          SizedBox(
            width: width / 2 - 10,
            height: controlRowHeight,
            child: SegmentedButton<SheetSegment>(
              showSelectedIcon: false,
              expandedInsets: EdgeInsets.zero,
              style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(0, controlRowHeight)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
              ),
              segments: const [
                ButtonSegment(value: SheetSegment.route, label: Text('Route')),
                ButtonSegment(value: SheetSegment.options, label: Text('Options')),
              ],
              selected: {segment},
              onSelectionChanged: (s) => onSegment(s.first),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: onLocation,
              style: buttonStyle,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  switch (locationMode) {
                    LocationMode.free => Icons.location_searching,
                    LocationMode.centered => Icons.my_location,
                    LocationMode.headingUp => Icons.navigation,
                  },
                  key: ValueKey(locationMode),
                  color: locationMode == LocationMode.free
                      ? null
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: onCompass,
              style: buttonStyle,
              child: Tooltip(
                message: 'Face north',
                child: CompassNeedle(bearing: bearing),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

/// North-pointing needle that counter-rotates with the map bearing.
class CompassNeedle extends StatelessWidget {
  const CompassNeedle({super.key, required this.bearing, this.size = 26});

  final double bearing;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -bearing * math.pi / 180,
      child: CustomPaint(
        size: Size.square(size),
        painter: _NeedlePainter(
          north: const Color(0xFFE53935),
          south: Theme.of(context).colorScheme.onSurfaceVariant,
          label: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _NeedlePainter extends CustomPainter {
  _NeedlePainter({required this.north, required this.south, required this.label});

  final Color north;
  final Color south;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final h = size.height / 2, w = size.width * 0.16;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - h)
        ..lineTo(c.dx + w, c.dy)
        ..lineTo(c.dx - w, c.dy)
        ..close(),
      Paint()..color = north,
    );
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy + h)
        ..lineTo(c.dx + w, c.dy)
        ..lineTo(c.dx - w, c.dy)
        ..close(),
      Paint()
        ..color = south
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(_NeedlePainter old) =>
      old.north != north || old.south != south || old.label != label;
}
