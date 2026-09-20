import 'package:flutter/material.dart';

/// Fades and slides its child up into place once, the first time this
/// widget is mounted. Used to animate the "Detected ingredients"/nutrition
/// sections in, and each ingredient card as it streams in — relies on
/// there being no explicit key, so an item appended to an existing list is
/// the only one treated as newly-mounted (earlier items keep their already-
/// completed animation state, not replaying it on every rebuild).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child});

  final Widget child;

  @override
  State<FadeSlideIn> createState() => FadeSlideInState();
}

class FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}
