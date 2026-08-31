import 'package:flutter/foundation.dart';

class EpisodeTrackerSnapshotRevision {
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);
  static int get current => notifier.value;
  static void increment() => notifier.value++;
  static void invalidateTitle([dynamic sourceOrId, dynamic id]) => notifier.value++;
  static void invalidate() => notifier.value++;
}
