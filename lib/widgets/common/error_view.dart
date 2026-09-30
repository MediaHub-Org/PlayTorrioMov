import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/theme/app_colors.dart';
import '../../services/app_units.dart';

/// Full-screen error view with retry button.
///
/// [title] is required rather than defaulting to "Could not load movies":
/// with a default, Anime and Live TV both inherited it through
/// [BrowseScaffold] and told the user their *movies* had failed while the
/// line underneath said the anime catalog had. A required parameter makes
/// that the analyzer's problem instead of the reader's.
class ErrorView extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  final String title;

  const ErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    // A real failure's message is whatever the thrown exception's toString()
    // is -- a nested SocketException, a server body, anything -- so its
    // length is not this widget's to bound. Without a scrollable, a long one
    // at a large text size pushed the retry button thousands of pixels off
    // the bottom of the screen, the same shape of bug the cast sheet had:
    // scroll rather than clamp when the content is prose whose length this
    // widget does not control (#69).
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.rem(1.625)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: context.rem(3),
              color: Colors.orangeAccent,
            ),
            SizedBox(height: context.rem(0.875)),
            Text(
              title,
              style: const TextStyle(
                fontSize: AppType.title,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: context.rem(AppRem.sm)),
            Text(
              error ?? context.l10n.commonUnknownError,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.ink.withOpacity(0.58),
              ),
            ),
            SizedBox(height: context.rem(1.25)),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.commonTryAgain),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
