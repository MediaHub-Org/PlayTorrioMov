import 'profile_policy.dart';

class ProfileAsyncAuthorization {
  final ProfileFeature feature;

  const ProfileAsyncAuthorization(this.feature);

  static Future<ProfileAsyncAuthorization?> capture(ProfileFeature feature) async {
    return ProfileAsyncAuthorization(feature);
  }

  Future<T> run<T>(Future<T> Function() callback) => callback();
}
