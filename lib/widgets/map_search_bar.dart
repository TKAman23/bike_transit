import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bike_transit/models/place.dart';
import 'package:bike_transit/services/theme_service.dart';
import 'package:bike_transit/state/map_screen_controller.dart';

const double searchBarHeight = 56;

/// Top search bar with suggestions dropdown and hamburger menu (SRCH-1…4).
class MapSearchBar extends StatefulWidget {
  const MapSearchBar({super.key, required this.focusNode});

  final FocusNode focusNode;

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  final _text = TextEditingController();
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  bool _searching = false;
  int _query = 0;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (widget.focusNode.hasFocus) {
      _load(_text.text);
    } else {
      setState(() => _suggestions = []);
    }
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _load(value));
  }

  Future<void> _load(String value) async {
    final id = ++_query;
    setState(() => _searching = value.trim().isNotEmpty);
    final results = await context.read<MapScreenController>().suggestions(value);
    if (!mounted || id != _query) return;
    setState(() {
      _suggestions = widget.focusNode.hasFocus ? results : [];
      _searching = false;
    });
  }

  Future<void> _choose(PlaceSuggestion s) async {
    final c = context.read<MapScreenController>();
    widget.focusNode.unfocus();
    _text.clear();
    setState(() => _suggestions = []);
    await c.chooseSuggestion(s);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MapScreenController>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hint = switch (c.activeField) {
      EndpointField.departure => 'Set departure',
      EndpointField.parking => 'Search a bike parking spot',
      EndpointField.destination =>
        c.destination == null ? 'Where to?' : 'Change destination',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: 3,
          shadowColor: Colors.black38,
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: searchBarHeight,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.directions_bike, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _text,
                    focusNode: widget.focusNode,
                    onChanged: _onChanged,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (v) {
                      if (_suggestions.isNotEmpty) _choose(_suggestions.first);
                    },
                    decoration: InputDecoration(
                      hintText: hint,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isCollapsed: true,
                    ),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                if (_searching)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_text.text.isNotEmpty || widget.focusNode.hasFocus)
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _text.clear();
                      widget.focusNode.unfocus();
                      c.cancelActiveField();
                    },
                  )
                else if (c.destination != null)
                  IconButton(
                    tooltip: 'Clear destination',
                    icon: const Icon(Icons.close),
                    onPressed: c.clearDestination,
                  ),
                const _HamburgerMenu(),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _suggestions.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Material(
                    elevation: 3,
                    shadowColor: Colors.black38,
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        itemBuilder: (context, i) {
                          final s = _suggestions[i];
                          return ListTile(
                            dense: true,
                            leading: Icon(switch (s.kind) {
                              SuggestionKind.currentLocation => Icons.my_location,
                              SuggestionKind.recent => Icons.history,
                              SuggestionKind.typed => Icons.search,
                              SuggestionKind.prediction => Icons.place_outlined,
                            }),
                            title: Text(s.primaryText,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: s.secondaryText == null
                                ? null
                                : Text(s.secondaryText!,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => _choose(s),
                          );
                        },
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _HamburgerMenu extends StatelessWidget {
  const _HamburgerMenu();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final dark = theme.isDark(context);
    return MenuAnchor(
      alignmentOffset: const Offset(-150, 4),
      builder: (context, menu, _) => IconButton(
        tooltip: 'Menu',
        icon: const Icon(Icons.menu),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.person_outline),
          onPressed: () => Navigator.pushNamed(context, '/profile'),
          child: const Padding(
            padding: EdgeInsets.only(right: 24),
            child: Text('Profile'),
          ),
        ),
        MenuItemButton(
          closeOnActivate: false,
          leadingIcon: Icon(dark ? Icons.dark_mode : Icons.dark_mode_outlined),
          trailingIcon: Switch(
            value: dark,
            onChanged: (v) => context.read<ThemeService>().setDark(v),
          ),
          onPressed: () => context.read<ThemeService>().setDark(!dark),
          child: const Text('Dark mode'),
        ),
      ],
    );
  }
}
