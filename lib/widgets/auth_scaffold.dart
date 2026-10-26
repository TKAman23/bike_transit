import 'package:flutter/material.dart';

/// Shared shell for the sign-in pages: soft brand gradient, centered card and
/// a fade/slide entrance so auth pages feel consistent with the map screens.
class AuthScaffold extends StatefulWidget {
  const AuthScaffold({super.key, required this.children, this.leading});

  final List<Widget> children;
  final Widget? leading;

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final anim = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primary.withValues(alpha: 0.14),
              Theme.of(context).scaffoldBackgroundColor,
              colors.secondary.withValues(alpha: 0.10),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.05), end: Offset.zero)
                          .animate(anim),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: widget.children,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.leading != null)
                Positioned(top: 8, left: 8, child: widget.leading!),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round gradient badge with a bike icon.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [colors.primary, colors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(Icons.directions_bike, size: size * 0.5, color: colors.onPrimary),
      ),
    );
  }
}
