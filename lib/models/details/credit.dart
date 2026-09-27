/// One credited person, flattened from either a `CastMember` or a `CrewMember`
/// so the credits rail has a single card shape to render.
class Credit {
  final String name;

  /// What they did: the character for cast, the job for crew. Null when
  /// nobody told us -- an addon that sends bare name strings and a TMDB
  /// lookup that did not land both leave this empty.
  ///
  /// It used to fall back to the literal word "Cast", which read as a role
  /// every actor happened to share rather than as the missing data it was.
  /// The card reserves the line either way, so a blank one costs no
  /// alignment.
  final String? role;

  final String? profileUrl;

  const Credit({required this.name, this.role, this.profileUrl});
}
