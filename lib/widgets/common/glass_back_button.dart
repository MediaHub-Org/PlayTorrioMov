import 'dart:ui';

import 'package:flutter/material.dart';

/// The single back-navigation button design used across every page that
/// pushes content on top of the hub (Details, Search, and so on). Used to
/// diverge per page -- a frosted floating circle here, a plain icon in a
/// header bar there, `arrow_back_ios_rounded` in one place and
/// `arrow_back_ios_new_rounded` in another -- which read as inconsistent
/// even though each was a reasonable choice on its own. One widget, used
/// everywhere a page needs to pop itself, so it cannot drift again.
class GlassBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double size;

  const GlassBackButton({super.key, this.onPressed, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: size,
          ),
          onPressed: onPressed ?? () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(12),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
        ),
      ),
    );
  }
}
