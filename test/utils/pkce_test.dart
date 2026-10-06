// test/utils/pkce_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/utils/pkce.dart';

void main() {
  group('Pkce.newVerifier', () {
    test('lands inside the 43-128 char range, URL-safe, unpadded', () {
      final verifier = Pkce.newVerifier();
      expect(verifier.length, inInclusiveRange(43, 128));
      expect(verifier, matches(RegExp(r'^[A-Za-z0-9\-_]+$')));
    });

    test('a fresh verifier every call', () {
      expect(Pkce.newVerifier(), isNot(Pkce.newVerifier()));
    });
  });

  group('Pkce.challengeFor', () {
    test('matches the RFC 7636 appendix B vector', () {
      // The RFC's own example pair, so a wrong hash or encoding fails here
      // rather than as a rejected token exchange against a live server.
      expect(
        Pkce.challengeFor('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });
  });
}
