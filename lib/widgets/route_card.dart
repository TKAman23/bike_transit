import 'package:flutter/material.dart';

import 'package:bike_transit/models/route_option.dart';
import 'package:bike_transit/models/user_preferences.dart';
import 'package:bike_transit/utils/format.dart';
import 'package:bike_transit/widgets/route_parts.dart';

/// One suggested route (CARD-2…CARD-9, CARD-12).
class RouteCard extends StatelessWidget {
  const RouteCard({
    super.key,
    required this.route,
    required this.units,
    required this.expanded,
    required this.onTap,
    required this.onStart,
    this.isBest = false,
  });

  final RouteOption route;
  final Units units;
  final bool expanded;
  final bool isBest;
  final VoidCallback onTap;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final minutes = route.duration;
    final timeStyle = theme.textTheme.titleLarge?.copyWith(height: 1.1);
    final muted = theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant);

    final summary = <String>[
      if (route.climbM > 1) '+${Fmt.elevation(route.climbM, units)} climb',
      if (route.note != null) route.note!,
      if (isBest) 'Best match',
    ].join(' · ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: colors.surface,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thin accent, same color as this route's collapsed map line.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 5,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: route.accentColor,
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(4)),
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 4, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(Fmt.duration(minutes), style: timeStyle),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('arr ${Fmt.clock(context, route.arriveAt)}',
                                maxLines: 1, style: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SectionStrip(route: route, units: units),
                          if (summary.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(summary,
                                style: muted,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              AnimatedRotation(
                                turns: expanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 250),
                                child: Icon(Icons.keyboard_arrow_up,
                                    size: 20, color: colors.primary),
                              ),
                              const SizedBox(width: 2),
                              Text('Details',
                                  style: theme.textTheme.labelLarge
                                      ?.copyWith(color: colors.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Center(
                      child: IconButton.filledTonal(
                        tooltip: 'Start',
                        onPressed: onStart,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? RouteDetails(route: route, units: units)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Expanded detail between this card and the next (CARD-6…CARD-8).
class RouteDetails extends StatelessWidget {
  const RouteDetails({super.key, required this.route, required this.units});

  final RouteOption route;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Slightly darker than the card; gray when the card is white.
    final background = theme.brightness == Brightness.light
        ? const Color(0xFFF0F2F5)
        : theme.colorScheme.surfaceContainerHigh;
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in route.sections)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: s.type == SectionType.transit
                  ? _TransitDetail(section: s)
                  : _RideDetail(section: s, units: units),
            ),
          if (route.usesPersonalizedSpeed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Times personalized from your recorded rides.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _RideDetail extends StatelessWidget {
  const _RideDetail({required this.section, required this.units});

  final RouteSection section;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted =
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final e = section.elevation;
    final verb = section.type == SectionType.bike ? 'Bike' : 'Walk';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 12),
          child: MountainOutlineIcon(color: section.color),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$verb · ${Fmt.distance(section.distanceM, units)} · ${Fmt.duration(section.duration)}',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              if (e != null && e.elevationsM.length > 1) ...[
                SizedBox(
                  height: 44,
                  child: TerrainGraph(
                    profile: e,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Low ${Fmt.elevation(e.minM, units)} · High ${Fmt.elevation(e.maxM, units)} · +${Fmt.elevation(e.gainM, units)}',
                  style: muted,
                ),
              ] else
                Text('Elevation unavailable', style: muted),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransitDetail extends StatelessWidget {
  const _TransitDetail({required this.section});

  final RouteSection section;

  static const _maxStopsShown = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = section.transit!;
    final muted =
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final stops = t.stops;

    // Rows: stop, or null for the vertical ellipsis.
    final rows = <(TransitStop?, int)>[];
    if (stops.length > _maxStopsShown) {
      rows.addAll([(stops[0], 0), (stops[1], 1)]);
      rows.add((null, stops.length - 4));
      rows.addAll([(stops[stops.length - 2], stops.length - 2), (stops.last, stops.length - 1)]);
    } else {
      for (var i = 0; i < stops.length; i++) {
        rows.add((stops[i], i));
      }
      if (stops.length == 2 && t.stopCount > 1) {
        rows.insert(1, (null, t.stopCount - 1));
      }
    }

    String? rideBetween(int i) {
      if (i <= 0 || i >= stops.length) return null;
      final a = stops[i - 1].time, b = stops[i].time;
      if (a == null || b == null) return null;
      return Fmt.duration(b.difference(a));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TransitBadge(section: section, large: true),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  if (t.headsign != null) 'toward ${t.headsign}',
                  t.realtime ? 'live' : 'scheduled',
                  if (!t.withBike) 'bike stays parked',
                ].join(' · '),
                style: muted,
              ),
              const SizedBox(height: 6),
              for (final (stop, i) in rows)
                if (stop == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          child: Icon(Icons.more_vert, size: 16, color: section.color),
                        ),
                        const SizedBox(width: 8),
                        Text('$i ${i == 1 ? 'stop' : 'stops'}', style: muted),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: section.color, width: 2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            stop.name,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        if (rideBetween(i) case final ride?)
                          Text('+$ride  ', style: muted),
                        if (stop.time != null)
                          Text(Fmt.clock(context, stop.time!), style: muted),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
