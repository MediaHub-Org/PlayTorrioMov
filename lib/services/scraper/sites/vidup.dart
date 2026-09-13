import 'enc_dec_embed_scraper.dart';

/// vidup.to, resolved through the enc-dec.app pipeline.
///
/// The pipeline itself lives in [EncDecEmbedScraper]; this file is only the
/// three strings that make it vidup rather than vidfast.
class VidUpScraper extends EncDecEmbedScraper {
  @override
  String get domain => 'https://vidup.to';

  @override
  String get encDecSlug => 'vidup';

  @override
  String get displayName => 'VidUp';
}
