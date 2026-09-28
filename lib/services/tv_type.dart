import 'tv_mode_service.dart';

/// Font-size scaling for the app's smallest labels and badges on an actual
/// Android TV, where a phone-sized 9-10.5px reads as an illegible speck
/// from 8-10 feet away.
///
/// Targeted, not a system-wide type-scale rewrite: applied only at the 53
/// spots under 11px found by auditing every `fontSize:` literal in `lib/`
/// (630+ of them) -- there is no central type scale the rest already flow
/// through, so rewriting all of them was out of scope. See #80 in
/// docs/ROADMAP.md.
abstract final class TvType {
  /// Chosen so the worst offender the audit found (8.5px) clears 11px --
  /// the same threshold the audit itself used to flag a spot as
  /// undersized -- while the least-undersized (10.5px) lands at a
  /// comfortably legible ~14.7px without ballooning past its neighbors'
  /// relative proportions.
  static const double _scaleFactor = 1.4;

  /// [fontSize] unchanged everywhere but Android TV. [TvModeService.isTv]
  /// is resolved once at startup before the first frame, so this never
  /// needs to react to a later change -- there isn't one.
  static double scale(double fontSize) =>
      TvModeService.isTv.value ? fontSize * _scaleFactor : fontSize;
}
