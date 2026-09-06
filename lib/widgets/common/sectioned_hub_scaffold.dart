import 'package:flutter/material.dart';

import '../../utils/hub_controller.dart';

/// The `Scaffold > section content` shell shared by hubs that just switch a
/// flat list of sections (Watch, Read). Rebuilds whenever [HubController]
/// changes.
///
/// [SectionTopBar] is deliberately *not* rendered here even though this is
/// "the hub content area" -- this widget sits inside `NestedNavigator`
/// (see `HubPage`), so anything rendered here gets covered the moment a
/// page is pushed within the hub (Details, Search, ...). `SectionTopBar`
/// instead lives in `AdaptiveNavShell`, outside the nested navigator,
/// alongside the mobile bottom tab bar it mirrors.
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
          body: buildSection(activeSection),
        );
      },
    );
  }
}
