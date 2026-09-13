import 'enc_dec_embed_scraper.dart';

/// vidfast.vc, resolved through the enc-dec.app pipeline.
///
/// The pipeline itself lives in [EncDecEmbedScraper]; this file is only the
/// three strings that make it vidfast rather than vidup.
class VidFastScraper extends EncDecEmbedScraper {
  @override
  String get domain => 'https://vidfast.vc';

  @override
  String get encDecSlug => 'vidfast';

  @override
  String get displayName => 'VidFast';
}
