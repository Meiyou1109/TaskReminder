import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class SmartScrollWrapper extends StatelessWidget {
  final ScrollController controller;
  final List<Widget> children;

  const SmartScrollWrapper({
    super.key,
    required this.controller,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;

    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            final newOffset = controller.offset + event.scrollDelta.dy * 2;
            final maxExtent = controller.position.maxScrollExtent;
            final minExtent = controller.position.minScrollExtent;
            final targetOffset = newOffset.clamp(minExtent, maxExtent);

            controller.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
            );
          }
        },
        child: StretchingOverscrollIndicator(
          axisDirection: AxisDirection.down,
          child: ListView(
            controller: controller,
            physics: isMobile
                ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
                : const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(top: 40, bottom: 120),
            children: children,
          ),
        ),
      ),
    );
  }
}
