import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bike_transit/constants/route_constants.dart';
import 'package:bike_transit/models/trip_record.dart';
import 'package:bike_transit/models/user_preferences.dart';
import 'package:bike_transit/models/user_stats.dart';
import 'package:bike_transit/services/auth_service.dart';
import 'package:bike_transit/services/theme_service.dart';
import 'package:bike_transit/state/user_data_controller.dart';
import 'package:bike_transit/utils/format.dart';

/// Profile: statistics, trip history, password reset and theme (PROF-1…3).
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();
  bool _sendingReset = false;

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _resetPassword(String email) async {
    setState(() => _sendingReset = true);
    final message = await _auth.resetPassword(email: email);
    if (!mounted) return;
    setState(() => _sendingReset = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  /// Staggered fade/slide-in for each block of the page.
  Widget _staggered(int i, Widget child) {
    final anim = CurvedAnimation(
      parent: _intro,
      curve: Interval((i * 0.08).clamp(0, 0.6), 1, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<UserDataController>();
    final theme = Theme.of(context);
    final user = _auth.currentUser;
    final units = data.sessionPrefs.units;
    final stats = data.stats;
    final isDark = context.watch<ThemeService>().isDark(context);

    final blocks = <Widget>[
      _Header(
        email: user?.email ?? 'Signed out',
        name: user?.displayName,
        since: user?.metadata.creationTime,
      ),
      if (data.cloudError != null)
        Card(
          color: theme.colorScheme.errorContainer,
          child: ListTile(
            leading: const Icon(Icons.cloud_off),
            title: Text(data.cloudError!),
            trailing: TextButton(onPressed: data.reload, child: const Text('Retry')),
          ),
        ),
      _StatsGrid(stats: stats, units: units),
      _WeekChart(stats: stats, units: units),
      _RecentTrips(trips: data.trips.take(8).toList(), units: units),
      Card(
        child: Column(
          children: [
            SwitchListTile(
              secondary: Icon(isDark ? Icons.dark_mode : Icons.dark_mode_outlined),
              title: const Text('Dark mode'),
              value: isDark,
              onChanged: (v) => context.read<ThemeService>().setDark(v),
            ),
            const Divider(indent: 16, endIndent: 16),
            if (_auth.isPasswordUser && user?.email != null)
              ListTile(
                leading: const Icon(Icons.lock_reset),
                title: const Text('Reset password'),
                subtitle: Text('Send a reset link to ${user!.email}'),
                trailing: _sendingReset
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _sendingReset ? null : () => _resetPassword(user.email!),
              )
            else
              const ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Password'),
                subtitle: Text('Managed by your Google account'),
              ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: Icon(Icons.logout, color: theme.colorScheme.error),
              title: Text('Sign out', style: TextStyle(color: theme.colorScheme.error)),
              onTap: _signOut,
            ),
          ],
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: data.reload,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          itemCount: blocks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (_, i) => _staggered(i, blocks[i]),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.email, this.name, this.since});

  final String email;
  final String? name;
  final DateTime? since;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = (name?.isNotEmpty == true ? name! : email).characters.first.toUpperCase();
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: Text(initial,
              style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name ?? email,
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (name != null)
                Text(email,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              if (since != null)
                Text(
                  'Riding since ${MaterialLocalizations.of(context).formatMediumDate(since!)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.units});

  final UserStats stats;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final co2 = stats.co2SavedKg;
    final tiles = [
      _StatTile(Icons.directions_bike, 'Distance biked',
          Fmt.distance(stats.bikeDistanceM, units), RouteConstants.bikeColor),
      _StatTile(Icons.eco_outlined, 'CO₂ saved (est.)',
          '${co2.toStringAsFixed(co2 < 10 ? 1 : 0)} kg', const Color(0xFF43A047)),
      _StatTile(Icons.route, 'Trips', '${stats.tripCount}', theme.colorScheme.primary),
      _StatTile(Icons.timer_outlined, 'Moving time',
          Fmt.duration(Duration(seconds: stats.movingTimeS.round())), const Color(0xFFFB8C00)),
      _StatTile(Icons.speed, 'Avg. speed',
          stats.avgSpeedMps > 0 ? Fmt.speedFromMps(stats.avgSpeedMps, units) : '—',
          const Color(0xFF8E24AA)),
      _StatTile(Icons.terrain, 'Climbed', Fmt.elevation(stats.climbM, units),
          const Color(0xFF6D4C41)),
      _StatTile(Icons.directions_bus_outlined, 'By transit',
          Fmt.distance(stats.transitDistanceM, units), const Color(0xFFE65100)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.9,
          children: tiles,
        ),
        const SizedBox(height: 6),
        Text(
          'CO₂ saved assumes each biked ${Fmt.distanceUnit(units)} replaces a trip by '
          'an average passenger car (US EPA ≈ 400 g CO₂/mile, '
          '${RouteConstants.co2KgPerKmAvoided} kg/km).',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.icon, this.label, this.value, this.color);

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: theme.textTheme.titleLarge),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.stats, required this.units});

  final UserStats stats;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perUnit = units == Units.metric ? 1000.0 : 1609.344;
    final values = [for (final m in stats.last7DaysBikeM) m / perUnit];
    final maxY = values.fold(0.0, (a, b) => a > b ? a : b);
    final today = DateTime.now();
    final labels = [
      for (var i = 6; i >= 0; i--)
        MaterialLocalizations.of(context)
            .narrowWeekdays[today.subtract(Duration(days: i)).weekday % 7],
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last 7 days', style: theme.textTheme.titleMedium),
            Text('Distance biked (${Fmt.distanceUnit(units)})',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: BarChart(
                BarChartData(
                  maxY: maxY <= 0 ? 1 : maxY * 1.2,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(labels[v.toInt()],
                              style: theme.textTheme.bodySmall),
                        ),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < 7; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: values[i],
                          width: 18,
                          color: i == 6
                              ? theme.colorScheme.primary
                              : RouteConstants.bikeColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTrips extends StatelessWidget {
  const _RecentTrips({required this.trips, required this.units});

  final List<TripRecord> trips;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = MaterialLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Text('Recent trips', style: theme.textTheme.titleMedium),
            ),
            if (trips.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Text('Trips you navigate will appear here.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            for (final t in trips)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(t.destination.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${loc.formatShortDate(t.startedAt)} · ${t.sections.join(' → ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(Fmt.distance(t.bikeDistanceM, units),
                    style: theme.textTheme.labelLarge),
              ),
          ],
        ),
      ),
    );
  }
}
