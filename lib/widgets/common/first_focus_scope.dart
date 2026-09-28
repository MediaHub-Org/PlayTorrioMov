import 'package:flutter/material.dart';

/// Hands focus to its first focusable descendant once [ready] turns true,
/// exactly once — so a D-pad/keyboard viewer who lands on a catalog grid or
/// list before its items have arrived still gets a deterministic landing
/// spot, instead of whatever Flutter's default traversal happens to pick.
///
/// Extracted from `BrowseRowView`'s own `autofocusFirstItem`, which had this
/// same `FocusScopeNode` + one-shot `nextFocus()` logic inline before a
/// second page needed it -- kept as one widget rather than two copies
/// starting to drift, the same reasoning `BrowseRowView` itself was pulled
/// out of `AnimeSliderSection`/`IptvSliderSection` for.
///
/// [ready] flips from false to true once, not per-rebuild: pass
/// `!isLoading && items.isNotEmpty`, not a value that toggles back and
/// forth, or a later "false" is simply ignored (see [_maybeAutofocus]) and
/// the widget is left focused on stale content it should not still hold.
class FirstFocusScope extends StatefulWidget {
  final bool ready;
  final Widget child;

  const FirstFocusScope({
    super.key,
    required this.ready,
    required this.child,
  });

  @override
  State<FirstFocusScope> createState() => _FirstFocusScopeState();
}

class _FirstFocusScopeState extends State<FirstFocusScope> {
  final FocusScopeNode _scope = FocusScopeNode(
    debugLabel: 'FirstFocusScope',
  );
  bool _didAutofocus = false;

  @override
  void initState() {
    super.initState();
    _maybeAutofocus();
  }

  @override
  void didUpdateWidget(covariant FirstFocusScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Content commonly arrives after the first build (an async catalog
    // fetch), so the one-shot attempt in initState alone would usually find
    // nothing focusable yet.
    _maybeAutofocus();
  }

  void _maybeAutofocus() {
    if (_didAutofocus || !widget.ready) return;
    _didAutofocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scope.nextFocus();
    });
  }

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(node: _scope, child: widget.child);
  }
}
