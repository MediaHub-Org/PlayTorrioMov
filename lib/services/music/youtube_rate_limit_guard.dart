import 'dart:async';

class YoutubeRateLimitException implements Exception {
  YoutubeRateLimitException(this.message);

  final String message;

  @override
  String toString() => message;
}

class YoutubeRateLimitGuard {
  YoutubeRateLimitGuard._();

  static Future<void> _resolverTail = Future<void>.value();
  static DateTime? _lastResolveAttempt;
  static const Duration minimumResolveGap = Duration(seconds: 2);

  static DateTime? _cooldownUntil;
  static String? _lastReason;

  static bool get isLimited {
    final until = _cooldownUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  static Duration? get remaining {
    final until = _cooldownUntil;
    if (until == null) return null;
    final diff = until.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  static String get userMessage {
    final wait = remaining;
    final waitText = wait == null || wait == Duration.zero
        ? 'a short while'
        : _formatDuration(wait);
    return 'YouTube audio source is busy on this network. Will retry online stream resolving in $waitText.';
  }

  static String? get lastReason => _lastReason;

  static void throwIfLimited() {
    if (isLimited) {
      throw YoutubeRateLimitException(userMessage);
    }
  }

  static Future<T> runLowRequest<T>(Future<T> Function() action) {
    final previous = _resolverTail;
    final gate = Completer<void>();

    _resolverTail = previous.then<void>(
      (_) => gate.future,
      onError: (_) => gate.future,
    );

    return (() async {
      try {
        try {
          await previous;
        } catch (_) {}

        throwIfLimited();

        final last = _lastResolveAttempt;
        if (last != null) {
          final elapsed = DateTime.now().difference(last);
          final wait = minimumResolveGap - elapsed;
          if (!wait.isNegative && wait > Duration.zero) {
            await Future<void>.delayed(wait);
          }
        }

        throwIfLimited();
        _lastResolveAttempt = DateTime.now();

        try {
          return await action();
        } catch (error) {
          if (isRateLimitError(error)) {
            record(error);
          }
          rethrow;
        }
      } finally {
        if (!gate.isCompleted) {
          gate.complete();
        }
      }
    })();
  }

  static bool isRateLimitError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('rate-limit') ||
        text.contains('429') ||
        text.contains('too many requests') ||
        text.contains('sign in to confirm you’re not a bot') ||
        text.contains('sign in to confirm you\'re not a bot') ||
        text.contains('unusual traffic') ||
        text.contains('bot detection');
  }

  static void record(Object error, {Duration duration = const Duration(minutes: 5)}) {
    _lastReason = error.toString();
    _cooldownUntil = DateTime.now().add(duration);
  }

  static void clear() {
    _cooldownUntil = null;
    _lastReason = null;
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}
