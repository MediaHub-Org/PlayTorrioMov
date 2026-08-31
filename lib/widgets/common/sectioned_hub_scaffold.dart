import 'package:flutter/material.dart';

import '../../utils/hub_controller.dart';
import 'section_top_bar.dart';

/// The `Scaffold > Column[SectionTopBar(), Expanded(section)]` shell shared
/// by hubs that just switch a flat list of sections (Watch, Read). Rebuilds
/// whenever [HubController] changes.
///
/// Music opts out of this: its body is a `Stack` carrying ambient
/// background glow, a keyboard listener, and drawer/modal overlays, which
/// is a genuinely different shape, not a copy of this one.
class SectionedHubScaffold extends StatelessWidget {
  final String Function() activeSectionOf;
  final Widget Function(String activeSection) buildSection;

  const SectionedHubScaffold({
    super.key,
    required this.activeSectionOf,
    required this.buildSection,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HubController.instance,
      builder: (context, _) {
        final activeSection = activeSectionOf();
        return Scaffold(
          backgroundColor: const Color(0xFF080A0F),
          body: Column(
            children: [
              const SectionTopBar(),
              Expanded(child: buildSection(activeSection)),
            ],
          ),
        );
      },
    );
  }
}
