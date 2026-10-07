import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// PKCE (RFC 7636) for the installed-app OAuth flow -- Dropbox proves itself
/// with a code verifier instead of a client secret, which no copy of this
/// app could keep safe baked into it anyway. Kept as its own file rather
/// than inlined into the one service using it, so a second provider needing
/// the same two functions later has somewhere to share them from instead of
/// a second copy.
abstract final class Pkce {
  Pkce._();

  /// 64 random bytes, base64url-encoded without padding -- 86 chars of the
  /// URL-safe alphabet, inside the 43-128 range the RFC asks for.
  static String newVerifier() {
    final bytes = List<int>.generate(64, (_) => Random.secure().nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// The S256 challenge the authorize URL carries for [verifier].
  static String challengeFor(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}
