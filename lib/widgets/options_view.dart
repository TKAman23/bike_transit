import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bike_transit/models/user_preferences.dart';
import 'package:bike_transit/state/map_screen_controller.dart';
import 'package:bike_transit/state/user_data_controller.dart';
import 'package:bike_transit/utils/format.dart';

/// The `Options` segment: every route-suggestion preference (OPT-1…OPT-4).
class OptionsView extends StatelessWidget {
  const OptionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<UserDataController>();
    final map = context.read<MapScreenController>();
    final p = data.sessionPrefs;
    final units = p.units;
    final theme = Theme.of(context);
    void set(UserPreferences next) => data.updateSession(next);

    Future<void> save() async {
      final err = await data.saveSessionToCloud();
      map.notify(err ?? 'Saved as your default preferences.');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.cloudError != null)
            _Banner(
              icon: Icons.cloud_off,
              color: theme.colorScheme.errorContainer,
              text: data.cloudError!,
              actions: [TextButton(onPressed: data.reload, child: const Text('Retry'))],
            )
          else if (data.isNewUser)
            _Banner(
              icon: Icons.waving_hand_outlined,
              color: theme.colorScheme.primaryContainer,
              text: 'Welcome! Tell us how you ride. Save to keep these settings '
                  'for future sessions.',
              actions: [FilledButton(onPressed: save, child: const Text('Save'))],
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: data.hasSessionChanges && !data.isNewUser
                ? _Banner(
                    icon: Icons.tune,
                    color: theme.colorScheme.secondaryContainer,
                    text: 'Changes apply to this session only.',
                    actions: [
                      TextButton(
                          onPressed: data.resetSessionToCloud,
                          child: const Text('Reset')),
                      FilledButton(
                          onPressed: save, child: const Text('Save as default')),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
          const _Heading('Your riding'),
          _SliderTile(
            icon: Icons.speed,
            title: 'Biking speed',
            value: Fmt.speedFromKph(p.bikeSpeedKph, units),
            slider: Slider(
              min: 8,
              max: 35,
              divisions: 27,
              value: p.bikeSpeedKph.clamp(8, 35),
              onChanged: (v) => set(p.copyWith(bikeSpeedKph: v)),
            ),
          ),
          _SliderTile(
            icon: Icons.battery_charging_full,
            title: 'Endurance',
            subtitle: 'How far you ride comfortably before tiring',
            value:
                '${Fmt.kmToDisplay(p.enduranceKm, units).toStringAsFixed(0)} ${Fmt.distanceUnit(units)}',
            slider: Slider(
              min: 2,
              max: 80,
              divisions: 78,
              value: p.enduranceKm.clamp(2, 80),
              onChanged: (v) => set(p.copyWith(enduranceKm: v)),
            ),
          ),
          _SliderTile(
            icon: Icons.terrain,
            title: 'Elevation gain',
            value: p.hillTolerance < 0.34
                ? 'Avoid hills'
                : p.hillTolerance < 0.67
                    ? 'Some hills OK'
                    : 'Hills are fine',
            slider: Slider(
              value: p.hillTolerance,
              divisions: 10,
              onChanged: (v) => set(p.copyWith(hillTolerance: v)),
            ),
            minLabel: 'Avoid',
            maxLabel: "Don't mind",
          ),
          const _Heading('Route ranking'),
          _SliderTile(
            icon: Icons.balance,
            title: 'Speed vs. strain',
            value: p.speedStrainWeight < 0.34
                ? 'Least effort'
                : p.speedStrainWeight < 0.67
                    ? 'Balanced'
                    : 'Fastest',
            slider: Slider(
              value: p.speedStrainWeight,
              divisions: 10,
              onChanged: (v) => set(p.copyWith(speedStrainWeight: v)),
            ),
            minLabel: 'Least effort',
            maxLabel: 'Fastest',
          ),
          _Tile(
            icon: Icons.directions_bus_outlined,
            title: 'Public transit',
            subtitle: 'Mix bus and light rail into bike routes',
            trailing: Switch(
              value: p.transitEnabled,
              onChanged: (v) => set(p.copyWith(transitEnabled: v)),
            ),
          ),
          _Tile(
            icon: Icons.straighten,
            title: 'Units',
            trailing: SegmentedButton<Units>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(value: Units.imperial, label: Text('mi')),
                ButtonSegment(value: Units.metric, label: Text('km')),
              ],
              selected: {units},
              onSelectionChanged: (s) => set(p.copyWith(units: s.first)),
            ),
          ),
          const _Heading('Bike parking'),
          Text(
            'Saved spots are used to end rides near your destination, or to '
            'park and continue by transit. Long-press the map to drop one.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          for (final spot in data.parking)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_parking),
              title: Text(spot.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final err = await data.removeParking(spot.id);
                  if (err != null) map.notify(err);
                },
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => map.focusEndpoint(EndpointField.parking),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add from search'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: 1.1,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge),
                if (subtitle != null)
                  Text(subtitle!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.slider,
    this.subtitle,
    this.minLabel,
    this.maxLabel,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String value;
  final Widget slider;
  final String? minLabel;
  final String? maxLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted =
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 22),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text(
                  value,
                  key: ValueKey(value),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(subtitle!, style: muted),
            ),
          Padding(padding: const EdgeInsets.only(left: 22), child: slider),
          if (minLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text(minLabel!, style: muted), Text(maxLabel!, style: muted)],
              ),
            ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.text,
    this.actions = const [],
  });

  final IconData icon;
  final Color color;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(text)),
            ],
          ),
          if (actions.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final a in actions)
                  Padding(padding: const EdgeInsets.only(left: 6), child: a),
              ],
            ),
        ],
      ),
    );
  }
}
