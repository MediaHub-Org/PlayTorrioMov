import 'package:flutter/material.dart';
import '../../app_info.dart';
import '../../services/app_breakpoints.dart';

/// The app's logo and wordmark, shown in the header.
///
/// The wordmark shows at every width -- a header with only an icon does not
/// tell a new user what they have opened. It is a little smaller on phones,
/// where the header also carries the settings button.
class SidebarLogo extends StatelessWidget {
  const SidebarLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.of(context) == ScreenTier.mobile;
    final iconSize = isMobile ? 26.0 : 32.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/icon.png',
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
        ),
        SizedBox(width: isMobile ? 8 : 10),
        Flexible(
          child: Text(
            AppInfo.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: isMobile ? 16 : 18,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }
}