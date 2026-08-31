class ParseTorrentTitle {
  final List<_Handler> _handlers = [];

  ParseTorrentTitle() {
    _addDefaults();
    _addTorrServerHandlers();
  }

  void _addDefaults() {
    // Year
    addHandler('year', RegExp(r'[^a-zA-Z0-9](?!^)[([\]]?((?:19[0-9]|20[012])[0-9])[)\]]?'), type: 'integer');

    // Resolution
    addHandler('resolution', RegExp(r'([0-9]{3,4}[pi])', caseSensitive: false), type: 'lowercase');
    addHandler('resolution', RegExp(r'\b(4k)', caseSensitive: false), type: 'lowercase');
    addHandler('resolution', RegExp(r'FHD|\b1080\b', caseSensitive: false), value: '1080p');
    addHandler('resolution', RegExp(r'UHD', caseSensitive: false), value: '4k');

    // Extended
    addHandler('extended', RegExp(r'EXTENDED(?:[\s.]CUT)?', caseSensitive: false), type: 'boolean');

    // Theatrical
    addHandler('theatrical', RegExp(r'Theatrical(?:[. ]Cut)?'), type: 'boolean');

    // Uncut
    addHandler('uncut', RegExp(r'.+\bUNCUT\b', caseSensitive: false), type: 'boolean');

    // Open Matte
    addHandler('openmatte', RegExp(r'OPEN[. ]MATTE', caseSensitive: false), type: 'boolean');

    // Downscaled
    addHandler('downscaled', RegExp(r'\bDS4K\b', caseSensitive: false), value: '4k');

    // Hybrid
    addHandler('hybrid', RegExp(r'\bhybrid(\b|\d)', caseSensitive: false), type: 'boolean');

    // Convert
    addHandler('convert', RegExp(r'CONVERT'), type: 'boolean');

    // Hardcoded
    addHandler('hardcoded', RegExp(r'HC|HARDCODED'), type: 'boolean');

    // Remux
    addHandler('remux', RegExp(r'REMUX', caseSensitive: false), type: 'boolean');

    // Proper
    addHandler('proper', RegExp(r'\b(?:REAL.)?PROPER\b', caseSensitive: false), type: 'boolean');

    // Repack
    addHandler('repack', RegExp(r'REPACK|RERIP', caseSensitive: false), type: 'boolean');

    // Internal
    addHandler('internal', RegExp(r'\b[iI]NTERNAL\b'), type: 'boolean');

    // Retail
    addHandler('retail', RegExp(r'\bRetail\b', caseSensitive: false), type: 'boolean');

    // Remastered
    addHandler('remastered', RegExp(r'\bRemaster(?:ed)?\b', caseSensitive: false), type: 'boolean');

    // Unrated
    addHandler('unrated', RegExp(r'\bunrated|uncensored\b', caseSensitive: false), type: 'boolean');

    // Extras
    addHandler('extras', RegExp(r'(?<=\b[12]\d{3}\b).*(\b|\.)\b(Extras?|Bonus|Extended[ ._-]Clip|Special Feature[s]?)\b', caseSensitive: false), type: 'boolean');

    // Criterion
    addHandler('criterion', RegExp(r'\bCriterion\b'), type: 'boolean');

    // Region
    addHandler('region', RegExp(r'(?:\b|[Dd](?:vd|VD))(R[0-9])'));

    // Container
    addHandler('container', RegExp(r'\b(MKV|AVI|MP4)\b', caseSensitive: false), type: 'lowercase');

    // Source
    addHandler('source', RegExp(r'\b(?:HD-?)?CAM\b'), type: 'lowercase');
    addHandler('source', RegExp(r'\b(?:HD-?)?T(?:ELE)?S(?:YNC)?\b', caseSensitive: false), value: 'telesync');
    addHandler('source', RegExp(r'\bHD-?Rip\b', caseSensitive: false), type: 'lowercase');
    addHandler('source', RegExp(r'\bBRRip\b', caseSensitive: false), type: 'lowercase');
    addHandler('source', RegExp(r'\bBDRip|BluRayRip\b', caseSensitive: false), value: 'bdrip');
    addHandler('source', RegExp(r'\bDVDRip\b', caseSensitive: false), type: 'lowercase');
    addHandler('source', RegExp(r'\bDVD(?:R[0-9])?\b', caseSensitive: false), value: 'dvd');
    addHandler('source', RegExp(r'\bDVDscr\b', caseSensitive: false), type: 'lowercase');
    addHandler('source', RegExp(r'\b(?:HD-?)?TVRip\b', caseSensitive: false), type: 'lowercase');
    addHandler('source', RegExp(r'\bTC\b'), type: 'lowercase');
    addHandler('source', RegExp(r'\bPPVRip\b', caseSensitive: false), type: 'lowercase');
    addHandler('source', RegExp(r'\bR5\b', caseSensitive: false), type: 'lowercase');
    addHandler('source', RegExp(r'\bVHSSCR\b', caseSensitive: false), type: 'lowercase');
    addHandler('source', RegExp(r'((?:\bBlu-?Ray)|((?:\b|\d)BR))\b', caseSensitive: false), value: 'bluray');
    addHandler('source', RegExp(r'\bWEB(?:-?DL)?\b(?!-?RIP)', caseSensitive: false), value: 'web-dl');
    addHandler('source', RegExp(r'\bWEB-?Rip\b', caseSensitive: false), type: 'lowercase');
    addHandler('source', RegExp(r'\b(?:DL|WEB|BD|BR)MUX\b', caseSensitive: false), type: 'lowercase');
    addHandler('source', RegExp(r'\b(DivX|XviD)\b'), type: 'lowercase');
    addHandler('source', RegExp(r'HDTV', caseSensitive: false), type: 'lowercase');
    addHandler('source', RegExp(r'\bIMAX[. -]Enhanced\b', caseSensitive: false), value: 'imax-enhanced');
    addHandler('source', RegExp(r'\bIMAX\b', caseSensitive: false), type: 'lowercase');
    addHandler('source', RegExp(r'\bHDDVD\b', caseSensitive: false), type: 'lowercase');
    addHandler('source', RegExp(r'\bNTSC\b', caseSensitive: false), type: 'lowercase');
    addHandler('source', RegExp(r'\bPAL\b', caseSensitive: false), type: 'lowercase');

    // Service
    addHandler('service', RegExp(r'\bAMZN|Amazon\b', caseSensitive: false), value: 'AMZN');
    addHandler('service', RegExp(r'\bAUBC\b', caseSensitive: false), type: 'uppercase');
    addHandler('service', RegExp(r'\bATVP\b', caseSensitive: false), type: 'uppercase');
    addHandler('service', RegExp(r'\bBNGE\b', caseSensitive: false), type: 'uppercase');
    addHandler('service', RegExp(r'\bDLWP\b', caseSensitive: false), type: 'uppercase');
    addHandler('service', RegExp(r'\bDSCP\b', caseSensitive: false), type: 'uppercase');
    addHandler('service', RegExp(r'\bDSNP\b', caseSensitive: false), type: 'uppercase');
    addHandler('service', RegExp(r'\bFDNG\b', caseSensitive: false), type: 'uppercase');
    addHandler('service', RegExp(r'\bHULU\b', caseSensitive: false), type: 'uppercase');
    addHandler('service', RegExp(r'\bH?MAX\b'), value: 'HMAX');
    addHandler('service', RegExp(r'\b(?<!DTS-HD[\s\-\.])MA\b', caseSensitive: false), type: 'uppercase');
    addHandler('service', RegExp(r'\b(NFLX|NF|Netflix)\b', caseSensitive: false), value: 'NFLX');
    addHandler('service', RegExp(r'\biT(?:unes)\b'), value: 'iT');
    addHandler('service', RegExp(r'\bPCOK\b', caseSensitive: false), type: 'uppercase');
    addHandler('service', RegExp(r'\bROKU\b', caseSensitive: false), type: 'uppercase');
    addHandler('service', RegExp(r'\bSKST\b', caseSensitive: false), type: 'uppercase');
    addHandler('service', RegExp(r'\bSTAN\b', caseSensitive: false), type: 'uppercase');

    // Codec
    addHandler('codec', RegExp(r'h[-. ]?265|hevc', caseSensitive: false), value: 'h265');
    addHandler('codec', RegExp(r'h[-. ]?264|avc', caseSensitive: false), value: 'h264');
    addHandler('codec', RegExp(r'dvix|mpeg2|divx|xvid|x[-. ]?26[45]', caseSensitive: false), type: 'lowercase');
    addCustomHandler('codec', (match, result) {
      if (result.containsKey('codec')) {
        result['codec'] = result['codec'].toString().replaceAll(RegExp(r'[ .-]'), '');
      }
      return null;
    });

    // Color
    addHandler('color', RegExp(r'\bHDR(?:10)?\b', caseSensitive: false), value: 'HDR');
    addHandler('color', RegExp(r'\bSDR\b', caseSensitive: false), type: 'uppercase');
    addHandler('color', RegExp(r'\b(?:DV|DoVi|Dolby\sVision)\b', caseSensitive: false), value: 'DV');

    // Audio
    addHandler('audio', RegExp(r'\bATMOS\b|DA\d', caseSensitive: false), value: 'atmos');
    addHandler('audio', RegExp(r'MD|MP3|mp3|FLAC|TrueHD'), type: 'lowercase');
    addHandler('audio', RegExp(r'\bDD-EX(\b|\d)', caseSensitive: false), value: 'dd-ex');
    addHandler('audio', RegExp(r'\bDD(?:\+|P)|EAC-?3', caseSensitive: false), value: 'ddp');
    addHandler('audio', RegExp(r'\b(DD(?!-EX)(?:\b|\d)|AC-?3)', caseSensitive: false), value: 'dd');
    addHandler('audio', RegExp(r'AAC(?:[. ]?2[. ]0)?'), value: 'aac');
    addHandler('audio', RegExp(r'DTS-ES'), type: 'lowercase');
    addHandler('audio', RegExp(r'DTS-HD[\s-.]?(MA|Master Audio)'), value: 'dts-hd-ma');
    addHandler('audio', RegExp(r'DTS(?:[- ]?HD)'), value: 'dts-hd', skipIfAlreadyFound: true);
    addHandler('audio', RegExp(r'DTS'), value: 'dts', skipIfAlreadyFound: true);

    // Channels
    addHandler('channels', RegExp(r'\d+[.\s](?:1|0)\b', caseSensitive: false));
    addHandler('channels', RegExp(r'2(?:ch)'), value: 2.0);
    addHandler('channels', RegExp(r'6(?:ch)'), value: 5.1);
    addHandler('channels', RegExp(r'8(?:ch)'), value: 7.1);
    addCustomHandler('channels', (match, result) {
      if (result.containsKey('channels') && result['channels'] is String) {
        result['channels'] = double.tryParse(result['channels'].toString().replaceAll(' ', '.')) ?? result['channels'];
      }
      return null;
    });

    // Bit depth
    addHandler('bitdepth', RegExp(r'\b(8|10|12|16|24)[-\s.]?bits?\b', caseSensitive: false), type: 'integer');

    // Sample Rate
    addHandler('samplerate', RegExp(r'\b((?:\d+)(?:\.\d+)?)[-\s.]?kHz?\b', caseSensitive: false), type: 'float');

    // Group
    addHandler('group', RegExp(r'-[ ([]*(?:\w+[ \][)]+)?(\w+(?:\.\w+)?(?<!\.mkv|\.mp4))[)\]]?(?:\.(?:mkv|mp4))?$', caseSensitive: false));

    // Encoder
    addHandler('encoder', RegExp(r'-[ ([]*(?:(\w+)[ \][)]+)\w+(?:\.\w+)?(?<!\.mkv|\.mp4)[)\]]?(?:\.(?:mkv|mp4))?$', caseSensitive: false));

    // Season
    addHandler('season', RegExp(r'([0-9]{1,2})xall', caseSensitive: false), type: 'integer');
    addHandler('season', RegExp(r'S([0-9]{1,2}) ?E[0-9]{1,2}', caseSensitive: false), type: 'integer');
    addHandler('season', RegExp(r'([0-9]{1,2})x[0-9]{1,2}'), type: 'integer');
    addHandler('season', RegExp(r'(?:Saison|Season)[. _-]?([0-9]{1,2})', caseSensitive: false), type: 'integer');
    addHandler('season', RegExp(r'\bS([0-9]{1,2})(?![0-9])', caseSensitive: false), type: 'integer');

    // Episode
    addHandler('episode', RegExp(r'S[0-9]{1,2} ?E([0-9]{1,5})', caseSensitive: false), type: 'integer');
    addHandler('episode', RegExp(r'[0-9]{1,2}x([0-9]{1,5})'), type: 'integer');
    addHandler('episode', RegExp(r'[ée]p(?:isode)?[. _-]?([0-9]{1,5})', caseSensitive: false), type: 'integer');

    // Language
    addHandler('language', RegExp(r'\bMULTi(?:Lang|-audio|-VF2)?\b', caseSensitive: false), value: 'multi');
    addHandler('language', RegExp(r'Dual(?:[- ]Audio)?|[ .]DL[ .]', caseSensitive: false), value: 'dual');
    addHandler('language', RegExp(r'\bRUS\b', caseSensitive: false), type: 'lowercase');
    addHandler('language', RegExp(r'\bUKR\b', caseSensitive: false), type: 'lowercase');
    addHandler('language', RegExp(r'\bJPN\b', caseSensitive: false), type: 'lowercase');
    addHandler('language', RegExp(r'\bENG(?:LISH)?\b', caseSensitive: false), value: 'eng');
    addHandler('language', RegExp(r'\bNL\b'), type: 'lowercase');
    addHandler('language', RegExp(r'\bNORDiC\b'), type: 'lowercase');
    addHandler('language', RegExp(r'\bViETNAM\b'), type: 'lowercase');
    addHandler('language', RegExp(r'\bFLEMISH\b'), type: 'lowercase');
    addHandler('language', RegExp(r'\bGERMAN\b', caseSensitive: false), type: 'lowercase');
    addHandler('language', RegExp(r'\bDUBBED\b'), type: 'lowercase');
    addHandler('language', RegExp(r'\bNORDIC\b'), type: 'lowercase');
    addHandler('language', RegExp(r'\bRoSubbed\b', caseSensitive: false), value: 'romanian');
    addHandler('language', RegExp(r'\b(ITA(?:LIAN)?|iTA(?:LiAN)?)\b'), value: 'ita');
    addHandler('language', RegExp(r'\bFR(?:ENCH)?\b'), type: 'lowercase');
    addHandler('language', RegExp(r'\bTruefrench|VF(?:[FI])\b', caseSensitive: false), type: 'lowercase');
    addHandler('language', RegExp(r'\bVOST(?:(?:F(?:R)?)|A)?|SUBFRENCH\b', caseSensitive: false), type: 'lowercase');
  }

  void _addTorrServerHandlers() {
    // Russian episode detection support
    addHandler('episode', RegExp(r'(\d{1,4})[- |. ]серия|серия[- |. ](\d{1,4})', caseSensitive: false), type: 'integer');
    addHandler('season', RegExp(r'sezon[- |. ](\d{1,3})|(\d{1,3})[- |. ]sezon', caseSensitive: false), type: 'integer');
    addHandler('season', RegExp(r'сезон[- |. ](\d{1,3})|(\d{1,3})[- |. ]сезон', caseSensitive: false), type: 'integer');
  }

  void addHandler(String name, RegExp regExp, {dynamic value, String? type, bool skipIfAlreadyFound = false}) {
    int? handler(String title, Map<String, dynamic> result) {
      if (result.containsKey(name) && skipIfAlreadyFound) {
        return null;
      }

      final match = regExp.firstMatch(title);
      if (match != null) {
        String rawMatch = match.group(0)!;
        String? cleanMatch = match.groupCount > 0 ? (match.group(1) ?? match.group(match.groupCount)) : null;
        
        dynamic finalValue = value;
        if (finalValue == null) {
          String input = cleanMatch ?? rawMatch;
          if (type == 'lowercase') {
            finalValue = input.toLowerCase();
          } else if (type == 'uppercase') {
            finalValue = input.toUpperCase();
          } else if (type == 'boolean') {
            finalValue = true;
          } else if (type == 'integer') {
            finalValue = int.tryParse(input);
          } else if (type == 'float') {
            finalValue = double.tryParse(input);
          } else {
            finalValue = input;
          }
        }

        if (!skipIfAlreadyFound && result.containsKey(name) && result[name] != finalValue) {
          final listKey = '${name}list';
          final list = result[listKey] as List<dynamic>? ?? [result[name]];
          if (!list.contains(finalValue)) {
            list.add(finalValue);
          }
          result[listKey] = list;
        }
        
        if (!result.containsKey(name)) {
          result[name] = finalValue;
        }
        
        return match.start;
      }

      return null;
    }
    
    _handlers.add(_Handler(name, handler));
  }

  void addCustomHandler(String name, int? Function(String title, Map<String, dynamic> result) handler) {
    _handlers.add(_Handler(name, handler));
  }

  String _cleanTitle(String rawTitle) {
    String cleanedTitle = rawTitle.replaceAll(RegExp(r'^\.+|\.+$'), '');

    if (!cleanedTitle.contains(' ') && cleanedTitle.contains('.')) {
      cleanedTitle = cleanedTitle.replaceAll('.', ' ');
    }

    cleanedTitle = cleanedTitle.replaceAll('_', ' ');
    cleanedTitle = cleanedTitle.replaceAll(RegExp(r'([(_]|- )$'), '').trim();

    return cleanedTitle;
  }

  Map<String, dynamic> parse(String title) {
    final Map<String, dynamic> result = {};
    int endOfTitle = title.length;

    for (final handler in _handlers) {
      final matchIndex = handler.func(title, result);

      if (matchIndex != null && matchIndex < endOfTitle) {
        endOfTitle = matchIndex;
      }
    }

    result['title'] = _cleanTitle(title.substring(0, endOfTitle));

    return result;
  }
}

class _Handler {
  final String name;
  final int? Function(String title, Map<String, dynamic> result) func;

  _Handler(this.name, this.func);
}
