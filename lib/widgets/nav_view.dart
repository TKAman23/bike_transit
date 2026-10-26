import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bike_transit/models/route_option.dart';
import 'package:bike_transit/models/user_preferences.dart';
import 'package:bike_transit/state/navigation_controller.dart';
import 'package:bike_transit/utils/format.dart';
import 'package:bike_transit/widgets/route_parts.dart';

const double _spineX = 22; // main spine, centered under the back button
const double _gutter = 44;
const double _headerHeight = 44;
const double _branchX = 16; // thinner section spine, inside the section body

/// En-route instructions: a continuous spine from the back arrow, with one
/// branch per section and the section's steps hanging off a thinner line.
class NavView extends StatelessWidget {
  const NavView({super.key, required this.units, required this.onBack});

  final Units units;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final spine = Theme.of(context).colorScheme.outline;
    final sections = nav.route.sections;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _gutter,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: onBack,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: const CircleBorder(),
                          ),
                          child: const Icon(Icons.arrow_back),
                        ),
                      ),
                      Expanded(
                        child: Container(width: 3, color: spine),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, top: 11, bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Back to routes',
                            style: Theme.of(context).textTheme.labelLarge),
                        if (nav.error != null)
                          Text(nav.error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < sections.length; i++)
            _SectionBlock(
              key: ValueKey('nav-section-$i'),
              section: sections[i],
              index: i,
              isLast: i == sections.length - 1,
              units: units,
              spineColor: spine,
            ),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatefulWidget {
  const _SectionBlock({
    super.key,
    required this.section,
    required this.index,
    required this.isLast,
    required this.units,
    required this.spineColor,
  });

  final RouteSection section;
  final int index;
  final bool isLast;
  final Units units;
  final Color spineColor;

  @override
  State<_SectionBlock> createState() => _SectionBlockState();
}

class _SectionBlockState extends State<_SectionBlock> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final s = widget.section;
    final i = widget.index;
    final done = i < nav.sectionIndex;
    final current = i == nav.sectionIndex;
    final theme = Theme.of(context);

    final header = SizedBox(
      height: _headerHeight,
      child: Row(
        children: [
          Container(width: 8, height: 2, color: s.color),
          const SizedBox(width: 4),
          switch (s.type) {
            SectionType.transit => TransitBadge(section: s, large: true),
            SectionType.bike => _RoundIcon(icon: Icons.directions_bike, color: s.color),
            SectionType.walk => _RoundIcon(icon: Icons.directions_walk, color: s.color),
          },
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _title(context, s),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: current ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (done) Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
        ],
      ),
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: done ? 0.45 : 1,
      // A Stack (not IntrinsicHeight) so the spine follows the animated height.
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _gutter,
            child: CustomPaint(
              painter: _MainSpinePainter(
                color: widget.spineColor,
                branchColor: s.color,
                isLast: widget.isLast,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: _gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                // Completed sections collapse so the current one stays near the top.
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  alignment: Alignment.topCenter,
                  child: done
                      ? const SizedBox(height: 6, width: double.infinity)
                      : _steps(context, nav, current),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _title(BuildContext context, RouteSection s) {
    final d = Fmt.distance(s.distanceM, widget.units);
    final t = Fmt.duration(s.duration);
    return switch (s.type) {
      SectionType.bike => 'Bike · $d · $t',
      SectionType.walk => 'Walk · $d · $t',
      SectionType.transit =>
        '${s.transit!.headsign != null ? 'to ${s.transit!.headsign}' : 'Ride'} · '
            '${s.transit!.realtime ? 'live ' : ''}${Fmt.clock(context, s.transit!.departureTime)}',
    };
  }

  Widget _steps(BuildContext context, NavigationController nav, bool current) {
    final steps = widget.section.steps;
    if (steps.isEmpty) return const SizedBox(height: 8, width: double.infinity);
    final active = current ? nav.stepIndex : -1;

    // Indices to show; null marks a vertical ellipsis (NAV-8).
    final shown = <int?>[];
    if (_showAll || steps.length <= 5) {
      shown.addAll(List.generate(steps.length, (k) => k));
    } else {
      final keep = <int>{0, 1, steps.length - 2, steps.length - 1};
      if (active >= 0) keep.addAll([active - 1, active, active + 1]);
      final sorted = keep.where((k) => k >= 0 && k < steps.length).toList()..sort();
      for (var k = 0; k < sorted.length; k++) {
        if (k > 0 && sorted[k] != sorted[k - 1] + 1) shown.add(null);
        shown.add(sorted[k]);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var k = 0; k < shown.length; k++)
            _StepRow(
              step: shown[k] == null ? null : steps[shown[k]!],
              hiddenCount: shown[k] == null
                  ? (shown[k + 1]! - shown[k - 1]! - 1)
                  : 0,
              isEdge: shown[k] == 0 || shown[k] == steps.length - 1,
              isCurrent: shown[k] != null && shown[k] == active,
              isLastRow: k == shown.length - 1,
              color: widget.section.color,
              onExpand: () => setState(() => _showAll = true),
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.hiddenCount,
    required this.isEdge,
    required this.isCurrent,
    required this.isLastRow,
    required this.color,
    required this.onExpand,
  });

  final NavStep? step;
  final int hiddenCount;
  final bool isEdge;
  final bool isCurrent;
  final bool isLastRow;
  final Color color;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = step;
    Widget content;
    if (s == null) {
      content = InkWell(
        onTap: onExpand,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(Icons.more_vert, size: 18, color: color),
              const SizedBox(width: 4),
              Text('$hiddenCount more',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    } else {
      final base = isEdge ? theme.textTheme.bodyMedium : theme.textTheme.bodySmall;
      final style = isCurrent
          ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
          : base;
      content = AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: isCurrent ? 10 : 4),
        decoration: BoxDecoration(
          color: isCurrent ? color.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          // Every step except the current one fades into the background (NAV-9).
          opacity: isCurrent ? 1 : 0.5,
          child: Row(
            children: [
              if (isCurrent) ...[
                Icon(_iconFor(s.maneuver), size: 22, color: color),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: style ?? const TextStyle(),
                  child: Text(s.instruction),
                ),
              ),
              if (s.time != null)
                Text(TimeOfDay.fromDateTime(s.time!.toLocal()).format(context),
                    style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 30,
          child: CustomPaint(
            painter: _BranchPainter(color: color, isLast: isLastRow, tick: s != null),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 30, top: 2, bottom: 2),
          child: content,
        ),
      ],
    );
  }

  static IconData _iconFor(String? maneuver) {
    final m = maneuver ?? '';
    if (m.contains('LEFT')) return Icons.turn_left;
    if (m.contains('RIGHT')) return Icons.turn_right;
    if (m.contains('UTURN')) return Icons.u_turn_left;
    if (m.contains('ROUNDABOUT')) return Icons.roundabout_left;
    return Icons.straight;
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

/// Main spine: vertical line through the gutter plus a branch into the header.
class _MainSpinePainter extends CustomPainter {
  _MainSpinePainter({
    required this.color,
    required this.branchColor,
    required this.isLast,
  });

  final Color color;
  final Color branchColor;
  final bool isLast;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = _headerHeight / 2;
    final spine = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        const Offset(_spineX, 0), Offset(_spineX, isLast ? mid : size.height), spine);
    canvas.drawLine(
      Offset(_spineX, mid),
      Offset(size.width, mid),
      Paint()
        ..color = branchColor
        ..strokeWidth = 2,
    );
    canvas.drawCircle(Offset(_spineX, mid), 4, Paint()..color = branchColor);
  }

  @override
  bool shouldRepaint(_MainSpinePainter old) =>
      old.color != color || old.branchColor != branchColor || old.isLast != isLast;
}

/// Thinner section spine that each step branches from.
class _BranchPainter extends CustomPainter {
  _BranchPainter({required this.color, required this.isLast, required this.tick});

  final Color color;
  final bool isLast;
  final bool tick;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1.4;
    final mid = size.height / 2;
    canvas.drawLine(const Offset(_branchX, 0),
        Offset(_branchX, isLast ? mid : size.height), p);
    if (tick) canvas.drawLine(Offset(_branchX, mid), Offset(size.width, mid), p);
  }

  @override
  bool shouldRepaint(_BranchPainter old) =>
      old.color != color || old.isLast != isLast || old.tick != tick;
}

/// The collapsed en-route control row (NAV-3).
class NavControlRow extends StatelessWidget {
  const NavControlRow({super.key, required this.onRecenter, required this.following});

  final VoidCallback onRecenter;
  final bool following;

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final theme = Theme.of(context);
    final section = nav.section;
    final nextLabel = nav.sectionIndex + 1 < nav.route.sections.length
        ? nav.route.sections[nav.sectionIndex + 1].label
        : 'arrival';
    return Row(
      children: [
        const SizedBox(width: 10),
        SizedBox(
          width: 50,
          height: 50,
          child: ElevatedButton(
            onPressed: onRecenter,
            style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
            child: Icon(following ? Icons.gps_fixed : Icons.gps_not_fixed),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: Fmt.duration(nav.timeRemaining),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                  TextSpan(
                    text: '  left · $nextLabel in ${Fmt.duration(nav.timeToNextSection)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Icon(
                    section.type == SectionType.transit
                        ? Icons.directions_bus
                        : Icons.subdirectory_arrow_right,
                    size: 15,
                    color: section.color,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Next: ${nav.nextInstruction}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}
