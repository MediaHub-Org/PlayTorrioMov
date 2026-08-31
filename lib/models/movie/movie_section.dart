import '../addon/addon.dart';
import 'movie.dart';

class MovieSection {
  final String title;
  final String subtitle;
  final String contentType;
  final String addonBaseUrl;
  final AddonCatalog catalog;
  final List<Movie> movies;

  MovieSection({
    required this.title,
    required this.subtitle,
    required this.contentType,
    required this.addonBaseUrl,
    required this.catalog,
    required this.movies,
  });
}
