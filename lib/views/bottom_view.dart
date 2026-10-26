import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// Header (control row + divider) height, excluding the bottom safe-area pad.
const double sheetHeaderHeight = 10 + 50 + 10 + 1;

/// The draggable sheet over the map (SHEET-1…3, 6, 12). It never closes: its
/// minimum extent always shows the control row and divider.
class BottomView extends StatelessWidget {
  const BottomView({
    super.key,
    required this.controller,
    required this.minExtent,
    required this.maxExtent,
    required this.initialExtent,
    required this.header,
    required this.body,
    required this.bottomInset,
  });

  final DraggableScrollableController controller;
  final double minExtent;
  final double maxExtent;
  final double initialExtent;
  final Widget header;
  final Widget body;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final snaps = [0.4]
        .where((s) => s > minExtent + 0.02 && s < maxExtent - 0.02)
        .toList();
    return DraggableScrollableSheet(
      controller: controller,
      minChildSize: minExtent,
      maxChildSize: maxExtent,
      initialChildSize: initialExtent.clamp(minExtent, maxExtent),
      snap: true,
      snapSizes: snaps,
      builder: (context, scroll) {
        // On web, keep clicks on the sheet from reaching the map underneath.
        return PointerInterceptor(
          child: Material(
            color: colors.surface,
            elevation: 8,
            shadowColor: Colors.black45,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: CustomScrollView(
              controller: scroll,
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _HeaderDelegate(
                    height: sheetHeaderHeight,
                    color: colors.surface,
                    child: header,
                  ),
                ),
                SliverToBoxAdapter(child: body),
                SliverToBoxAdapter(child: SizedBox(height: bottomInset + 24)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({
    required this.height,
    required this.color,
    required this.child,
  });

  final double height;
  final Color color;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: color,
      child: Column(
        children: [
          const SizedBox(height: 10),
          child,
          const SizedBox(height: 10),
          // Thin divider, inset from both edges (SHEET-12).
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Divider(height: 1, thickness: 1),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_HeaderDelegate old) =>
      old.child != child || old.color != color || old.height != height;
}
