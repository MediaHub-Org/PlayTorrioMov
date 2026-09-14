import 'package:flutter/material.dart';
import '../../services/theme/app_colors.dart';

/// Full-screen error view with retry button.
///
/// [title] is required rather than defaulting to "Could not load movies":
/// with a default, Anime and Live TV both inherited it through
/// [BrowseScaffold] and told the user their *movies* had failed while the
/// line underneath said the anime catalogue had. A required parameter makes
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.ink.withOpacity(0.58),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
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
