import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'package:bike_transit/constants/map_styles.dart';
import 'package:bike_transit/constants/route_constants.dart';
import 'package:bike_transit/models/route_option.dart';
import 'package:bike_transit/services/location_service.dart';
import 'package:bike_transit/state/map_screen_controller.dart';
import 'package:bike_transit/state/navigation_controller.dart';
import 'package:bike_transit/state/user_data_controller.dart';
import 'package:bike_transit/utils/geo.dart';
import 'package:bike_transit/views/bottom_view.dart';
import 'package:bike_transit/widgets/control_row.dart';
import 'package:bike_transit/widgets/map_search_bar.dart';
import 'package:bike_transit/widgets/nav_view.dart';
import 'package:bike_transit/widgets/options_view.dart';
import 'package:bike_transit/widgets/route_view.dart';

/// Home map screen: full-screen map with the search bar and BottomView stacked
/// over it (MAP-1/2).
class MapsView extends StatefulWidget {
  const MapsView({super.key});

  @override
  State<MapsView> createState() => _MapsViewState();
}

class _MapsViewState extends State<MapsView> {
  late final MapScreenController _c;
  final _sheet = DraggableScrollableController();
  final _searchFocus = FocusNode();
  final _bearing = ValueNotifier<double>(0);
  final List<StreamSubscription<Object?>> _subs = [];
  GoogleMapController? _map;
  NavigationController? _nav;
  StreamSubscription<double>? _headingSub;

  LocationMode _locationMode = LocationMode.free;
  CameraPosition _camera = const CameraPosition(
    target: RouteConstants.seattleCenter,
    zoom: RouteConstants.seattleZoom,
  );
  DateTime _programmaticUntil = DateTime.fromMillisecondsSinceEpoch(0);
  bool _followUser = true;
  double _targetExtent = 0.4;
  double? _initialExtent;
  double _minExtent = 0.12;
  double _maxExtent = 0.85;
  String _shownRoutesKey = '';
  int? _shownExpanded;
  int _contentIndex = 0;
  int _previousContentIndex = 0;

  @override
  void initState() {
    super.initState();
    final userData = context.read<UserDataController>();
    _c = MapScreenController(userData: userData);
    _c.addListener(_onState);
    _subs
      ..add(_c.sheetTargets.listen(_animateSheet))
      ..add(_c.searchFocusRequests.listen((_) => _searchFocus.requestFocus()))
      ..add(_c.messages.listen(_snack));
    _c.init();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _headingSub?.cancel();
    _nav?.dispose();
    _c.removeListener(_onState);
    _c.dispose();
    _sheet.dispose();
    _searchFocus.dispose();
    _bearing.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- State → map/sheet synchronization (MAP-3, ENDPT-4) ----

  void _onState() {
    // Enter / leave en-route mode.
    final navRoute = _c.navRoute;
    if (navRoute != null && _nav?.route != navRoute) {
      _nav?.dispose();
      _searchFocus.unfocus();
      final nav = NavigationController(
        route: navRoute,
        origin: _c.departure!,
        destination: _c.destination!,
        location: _c.location,
        onArrived: _onArrived,
      );
      nav.addListener(_onNavUpdate);
      _nav = nav;
      _followUser = true;
      _stopHeadingUp();
      nav.start();
      final first = navRoute.sections.first.path.first;
      _moveCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: _c.location.lastKnown ?? first, zoom: 17, tilt: 35)));
    } else if (navRoute == null && _nav != null) {
      _nav!.removeListener(_onNavUpdate);
      _nav!.dispose();
      _nav = null;
      _moveCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: _camera.target, zoom: _camera.zoom)));
    }

    if (_nav == null) {
      final key = _c.routes.map((r) => r.id + r.signature).join(',');
      if (key != _shownRoutesKey && _c.routes.isNotEmpty) {
        _fitTo(_c.routes.expand((r) => r.allPoints));
      } else if (_c.expandedIndex != _shownExpanded && _c.expandedRoute != null) {
        _fitTo(_c.expandedRoute!.allPoints);
      } else if (key != _shownRoutesKey && _c.destination != null) {
        _moveCamera(CameraUpdate.newLatLngZoom(_c.destination!.location, 15));
      }
      _shownRoutesKey = key;
      _shownExpanded = _c.expandedIndex;
    }

    final index = _c.navigating ? 2 : (_c.segment == SheetSegment.options ? 1 : 0);
    if (index != _contentIndex) {
      _previousContentIndex = _contentIndex;
      _contentIndex = index;
    }
    if (mounted) setState(() {});
  }

  void _onNavUpdate() {
    final nav = _nav;
    if (nav == null) return;
    final p = nav.position;
    if (_followUser && p != null) {
      _moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: p,
        zoom: 17,
        tilt: 35,
        bearing: nav.headingDeg ?? _camera.bearing,
      )));
    }
    setState(() {});
  }

  Future<void> _onArrived() async {
    final nav = _nav;
    if (nav == null) return;
    final err = await context.read<UserDataController>().recordTrip(nav.buildTrip());
    _snack(err == null
        ? 'You have arrived at ${nav.destination.name}. Trip saved.'
        : 'You have arrived. $err');
    _c.stopNavigation(finished: true);
  }

  Future<void> _exitNavigation() async {
    final nav = _nav;
    if (nav != null && nav.progressM > 100) {
      final err = await context.read<UserDataController>().recordTrip(nav.buildTrip());
      _snack(err ?? 'Partial ride saved to your history.');
    }
    _c.stopNavigation(finished: false);
  }

  // ---- Sheet ----

  void _animateSheet(SheetTarget target) {
    final size = switch (target) {
      SheetTarget.max => _maxExtent,
      SheetTarget.home => 0.4,
      SheetTarget.routes => 0.5,
      SheetTarget.min => _minExtent,
    }.clamp(_minExtent, _maxExtent);
    setState(() => _targetExtent = size);
    void run() {
      if (!_sheet.isAttached) return;
      _sheet.animateTo(size,
          duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    }

    if (_sheet.isAttached) {
      run();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => run());
    }
  }

  // ---- Camera ----

  void _moveCamera(CameraUpdate update) {
    final map = _map;
    if (map == null) return;
    _programmaticUntil = DateTime.now().add(const Duration(milliseconds: 1500));
    map.animateCamera(update);
  }

  void _fitTo(Iterable<LatLng> points) {
    if (points.isEmpty) return;
    _moveCamera(CameraUpdate.newLatLngBounds(Geo.bounds(points), 48));
  }

  void _onCameraMoveStarted() {
    if (DateTime.now().isBefore(_programmaticUntil)) return;
    // The rider moved the map by hand.
    if (_locationMode != LocationMode.free) {
      _stopHeadingUp();
      setState(() => _locationMode = LocationMode.free);
    }
    if (_nav != null && _followUser) setState(() => _followUser = false);
  }

  Future<void> _onLocationButton() async {
    final here = await _c.location.current();
    if (here == null) {
      _snack(_c.locationAccess == LocationAccess.serviceDisabled
          ? 'Turn on location services to center the map.'
          : 'Allow location access to center the map on you.');
      return;
    }
    switch (_locationMode) {
      case LocationMode.free:
        setState(() => _locationMode = LocationMode.centered);
        _moveCamera(CameraUpdate.newCameraPosition(
            CameraPosition(target: here, zoom: 16, bearing: _camera.bearing)));
      case LocationMode.centered:
        setState(() => _locationMode = LocationMode.headingUp);
        _startHeadingUp();
      case LocationMode.headingUp:
        _stopHeadingUp();
        setState(() => _locationMode = LocationMode.centered);
        _moveCamera(CameraUpdate.newCameraPosition(
            CameraPosition(target: here, zoom: _camera.zoom)));
    }
  }

  void _startHeadingUp() {
    _headingSub?.cancel();
    var last = DateTime.fromMillisecondsSinceEpoch(0);
    var received = false;
    _headingSub = _c.location.headings().listen((heading) {
      received = true;
      final now = DateTime.now();
      if (now.difference(last) < const Duration(milliseconds: 250)) return;
      last = now;
      _moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: _c.location.lastKnown ?? _camera.target,
        zoom: _camera.zoom,
        bearing: heading,
      )));
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (!received && _locationMode == LocationMode.headingUp && mounted) {
        _snack('No compass reading from this device; heading-up is unavailable.');
      }
    });
  }

  void _stopHeadingUp() {
    _headingSub?.cancel();
    _headingSub = null;
  }

  void _onCompass() {
    if (_locationMode == LocationMode.headingUp) {
      _stopHeadingUp();
      setState(() => _locationMode = LocationMode.centered);
    }
    _moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: _camera.target, zoom: _camera.zoom, tilt: 0, bearing: 0)));
  }

  void _recenter() {
    setState(() => _followUser = true);
    final p = _nav?.position ?? _c.location.lastKnown;
    if (p != null) {
      _moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: p, zoom: 17, tilt: 35, bearing: _nav?.headingDeg ?? 0)));
    }
  }

  // ---- Map gestures ----

  void _onMapTap(LatLng point) {
    if (_searchFocus.hasFocus) {
      _searchFocus.unfocus();
      return;
    }
    if (_c.navigating) return;
    if (_c.destination == null || _c.activeField != EndpointField.destination) {
      _c.dropPin(point);
    }
  }

  Future<void> _onMapLongPress(LatLng point) async {
    if (_c.navigating) return;
    final name = TextEditingController(text: 'Bike parking');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.local_parking),
        title: const Text('Save bike parking here?'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final label = name.text.trim().isEmpty ? 'Bike parking' : name.text.trim();
    final err = await context.read<UserDataController>().addParking(label, point);
    _snack(err ?? 'Saved "$label".');
  }

  // ---- Map overlays ----

  Set<Polyline> _polylines() {
    final out = <Polyline>{};
    final nav = _nav;
    if (nav != null) {
      final r = nav.route;
      for (var i = 0; i < r.sections.length; i++) {
        final s = r.sections[i];
        final (done, rest) = nav.splitSection(i);
        if (done.length > 1) {
          out.add(Polyline(
            polylineId: PolylineId('done$i'),
            points: done,
            color: s.color.withValues(alpha: 0.3),
            width: 6,
            zIndex: 1,
          ));
        }
        if (rest.length > 1) {
          out.add(_sectionLine('nav$i', s, s.color, 7, 2, points: rest));
        }
      }
      return out;
    }
    final expanded = _c.expandedIndex;
    for (var i = _c.routes.length - 1; i >= 0; i--) {
      final r = _c.routes[i];
      for (var j = 0; j < r.sections.length; j++) {
        final s = r.sections[j];
        final id = '${r.id}-$j';
        if (expanded == null) {
          out.add(_sectionLine(id, s, r.accentColor, i == 0 ? 7 : 5, 10 - i));
        } else if (expanded == i) {
          out.add(_sectionLine(id, s, s.color, 7, 20));
        } else {
          out.add(_sectionLine(id, s, RouteConstants.fadedRouteColor, 4, 0));
        }
      }
    }
    return out;
  }

  Polyline _sectionLine(String id, RouteSection s, Color color, int width, int z,
      {List<LatLng>? points}) {
    return Polyline(
      polylineId: PolylineId(id),
      points: points ?? s.path,
      color: color,
      width: width,
      zIndex: z,
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      patterns: s.type == SectionType.walk
          ? [PatternItem.dot, PatternItem.gap(10)]
          : const [],
    );
  }

  /// Web ignores marker hues, so the rider and bike-parking spots are drawn
  /// as colored dots there (native platforms use the location layer + pins).
  Set<Circle> _circles() {
    if (!kIsWeb) return const {};
    final out = <Circle>{};
    final me = _nav?.position ?? _c.location.lastKnown;
    if (me != null) {
      out.add(Circle(
        circleId: const CircleId('me'),
        center: me,
        radius: 14,
        zIndex: 30,
        fillColor: const Color(0xFF1A73E8),
        strokeColor: Colors.white,
        strokeWidth: 3,
      ));
    }
    if (_nav == null) {
      for (final p in context.watch<UserDataController>().parking) {
        out.add(Circle(
          circleId: CircleId('park-${p.id}'),
          center: p.location,
          radius: 22,
          zIndex: 20,
          fillColor: const Color(0xCC8E24AA),
          strokeColor: Colors.white,
          strokeWidth: 2,
        ));
      }
    }
    return out;
  }

  Set<Marker> _markers() {
    final userData = context.watch<UserDataController>();
    final out = <Marker>{};
    final from = _c.departure, to = _c.destination;
    if (from != null && !from.isCurrentLocation && _nav == null) {
      out.add(Marker(
        markerId: const MarkerId('from'),
        position: from.location,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: from.name),
      ));
    }
    if (to != null) {
      out.add(Marker(
        markerId: const MarkerId('to'),
        position: to.location,
        infoWindow: InfoWindow(title: to.name),
      ));
    }
    if (_nav == null && !kIsWeb) {
      for (final p in userData.parking) {
        out.add(Marker(
          markerId: MarkerId('park-${p.id}'),
          position: p.location,
          alpha: 0.85,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          infoWindow: InfoWindow(title: p.name, snippet: 'Saved bike parking'),
        ));
      }
    }
    return out;
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final navigating = _c.navigating;

    return ChangeNotifierProvider.value(
      value: _c,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(builder: (context, constraints) {
          final h = constraints.maxHeight;
          final searchTop = media.padding.top + 8;
          final searchBottom = searchTop + searchBarHeight;
          // Max: up to (not over) the search bar. Min: control row + divider.
          _maxExtent = ((h - searchBottom - 8) / h).clamp(0.3, 1.0);
          _minExtent = ((sheetHeaderHeight + 8) / h)
              .clamp(0.05, _maxExtent);
          // Fixed after the first build; later changes go through the controller.
          _initialExtent ??= context.read<UserDataController>().isNewUser ? _maxExtent : 0.4;

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: _camera,
                style: dark ? MapStyles.dark : MapStyles.light,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                compassEnabled: false,
                mapToolbarEnabled: false,
                indoorViewEnabled: false,
                buildingsEnabled: true,
                myLocationEnabled: _c.locationAccess == LocationAccess.granted,
                padding: EdgeInsets.only(
                  top: navigating ? media.padding.top : searchBottom,
                  bottom: h * _targetExtent.clamp(_minExtent, 0.55),
                ),
                polylines: _polylines(),
                markers: _markers(),
                circles: _circles(),
                onMapCreated: (controller) => _map = controller,
                onCameraMove: (p) {
                  _camera = p;
                  _bearing.value = p.bearing;
                },
                onCameraMoveStarted: _onCameraMoveStarted,
                onTap: _onMapTap,
                onLongPress: _onMapLongPress,
              ),
              BottomView(
                controller: _sheet,
                minExtent: _minExtent,
                maxExtent: _maxExtent,
                initialExtent: _initialExtent!,
                bottomInset: media.padding.bottom,
                header: navigating && _nav != null
                    ? ChangeNotifierProvider.value(
                        value: _nav!,
                        child: SizedBox(
                          height: controlRowHeight,
                          child: NavControlRow(
                            onRecenter: _recenter,
                            following: _followUser,
                          ),
                        ),
                      )
                    : ValueListenableBuilder<double>(
                        valueListenable: _bearing,
                        builder: (context, bearing, _) => ControlRow(
                          segment: _c.segment,
                          onSegment: _c.setSegment,
                          locationMode: _locationMode,
                          onLocation: _onLocationButton,
                          bearing: bearing,
                          onCompass: _onCompass,
                        ),
                      ),
                body: _SlideSwitcher(
                  index: _contentIndex,
                  previousIndex: _previousContentIndex,
                  child: switch (_contentIndex) {
                    2 when _nav != null => ChangeNotifierProvider.value(
                        value: _nav!,
                        child: NavView(
                          units: _c.prefs.units,
                          onBack: _exitNavigation,
                        ),
                      ),
                    1 => const OptionsView(),
                    _ => const RouteView(),
                  },
                ),
              ),
              Positioned(
                top: searchTop,
                left: 12,
                right: 12,
                child: IgnorePointer(
                  ignoring: navigating,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    offset: navigating ? const Offset(0, -0.6) : Offset.zero,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 260),
                      opacity: navigating ? 0 : 1,
                      child: Visibility(
                        visible: !navigating,
                        maintainState: true,
                        maintainAnimation: true,
                        maintainSize: true,
                        child: MapSearchBar(focusNode: _searchFocus),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Slides sheet content left/right when switching Route ↔ Options ↔ en-route.
class _SlideSwitcher extends StatelessWidget {
  const _SlideSwitcher({
    required this.index,
    required this.previousIndex,
    required this.child,
  });

  final int index;
  final int previousIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dir = index >= previousIndex ? 1.0 : -1.0;
    final key = ValueKey(index);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == key;
        return ClipRect(
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(incoming ? dir : -dir, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: key, child: child),
    );
  }
}
