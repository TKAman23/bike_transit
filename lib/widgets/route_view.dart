import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bike_transit/models/place.dart';
import 'package:bike_transit/state/map_screen_controller.dart';
import 'package:bike_transit/widgets/route_card.dart';

/// The `Route` segment: endpoints, then the route list or its empty state.
class RouteView extends StatelessWidget {
  const RouteView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MapScreenController>();
    final theme = Theme.of(context);
    final units = c.prefs.units;

    Widget body;
    if (c.destination == null) {
      body = const _EmptyState(
        icon: Icons.place_outlined,
        title: 'No destination selected',
        subtitle: 'Search above or tap the map to pick where you are going.',
      );
    } else if (c.loading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Column(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(height: 14),
            Text('Finding bike and transit routes…'),
          ],
        ),
      );
    } else if (c.routeError != null) {
      body = _EmptyState(
        icon: Icons.error_outline,
        title: 'No routes yet',
        subtitle: c.routeError!,
        action: TextButton.icon(
          onPressed: c.plan,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final n in c.notices)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(n,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
          for (var i = 0; i < c.routes.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            RouteCard(
              key: ValueKey(c.routes[i].id),
              route: c.routes[i],
              units: units,
              isBest: i == 0,
              expanded: c.expandedIndex == i,
              onTap: () => c.toggleRoute(i),
              onStart: () => c.startNavigation(i),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EndpointRow(),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(
            key: ValueKey(c.destination == null
                ? 'empty'
                : c.loading
                    ? 'loading'
                    : c.routeError ?? 'list'),
            child: body,
          ),
        ),
      ],
    );
  }
}

/// Departure and destination buttons (ENDPT-2/3).
class EndpointRow extends StatelessWidget {
  const EndpointRow({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MapScreenController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: Row(
        children: [
          Expanded(
            child: _EndpointButton(
              icon: Icons.trip_origin,
              label: 'From',
              place: c.departure,
              placeholder: 'Choose start',
              active: c.activeField == EndpointField.departure,
              onPressed: () => c.focusEndpoint(EndpointField.departure),
            ),
          ),
          IconButton(
            tooltip: 'Swap',
            visualDensity: VisualDensity.compact,
            onPressed: c.departure != null && c.destination != null
                ? c.swapEndpoints
                : null,
            icon: const Icon(Icons.swap_horiz),
          ),
          Expanded(
            child: _EndpointButton(
              icon: Icons.place,
              label: 'To',
              place: c.destination,
              placeholder: 'Choose destination',
              active: c.activeField == EndpointField.destination &&
                  c.destination == null,
              onPressed: () => c.focusEndpoint(EndpointField.destination),
            ),
          ),
        ],
      ),
    );
  }
}

class _EndpointButton extends StatelessWidget {
  const _EndpointButton({
    required this.icon,
    required this.label,
    required this.place,
    required this.placeholder,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Place? place;
  final String placeholder;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? colors.primary : colors.outlineVariant,
          width: active ? 1.6 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: text.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant)),
                      // Long names fade out instead of wrapping (ENDPT-2).
                      Text(
                        place?.name ?? placeholder,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: place == null ? colors.onSurfaceVariant : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 36, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}
