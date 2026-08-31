import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../services/books/book_progress_service.dart';
import '../../services/books/books_service.dart';

/// Reads an already-downloaded epub file.
///
/// Ported from PlayTorrioV2's `lib/screens/book_reader_screen.dart`: the
/// epub is unzipped once to a sibling folder, the OPF manifest/spine is
/// parsed into a chapter list, and each chapter's own HTML file is loaded
/// directly into a webview via a `file://` URL -- relative image/CSS
/// references inside the chapter resolve naturally against the extracted
/// folder, no custom URL scheme needed. A small JS snippet re-themes the
/// page (dark/light, font size) and reports scroll position back for
/// progress tracking.
///
/// V2's "focus mode" (one-line-at-a-time reading overlay) was left out --
/// a real feature, but a large chunk of extra JS/UI for a first version.
class BookReaderPage extends StatefulWidget {
  final File file;
  final String title;
  final BookResult? bookResult;
  final int initialChapter;

  const BookReaderPage({
    super.key,
    required this.file,
    required this.title,
    this.bookResult,
    this.initialChapter = 0,
  });

  @override
  State<BookReaderPage> createState() => _BookReaderPageState();
}

/// Resolves a zip entry name against [extractRoot], rejecting (returns null)
/// any entry whose normalized path would escape it -- e.g. `../../evil` or
/// an absolute path baked into the entry name. Zip Slip guard: EPUBs are
/// untrusted content from third-party scrape sources.
String? safeExtractPath(String extractRoot, String entryName) {
  final root = p.normalize(extractRoot);
  final target = p.normalize(p.join(root, entryName));
  if (p.equals(target, root) || p.isWithin(root, target)) {
    return target;
  }
  return null;
}

class _Chapter {
  final String filePath;
  final String title;
  const _Chapter({required this.filePath, required this.title});
}

class _ManifestItem {
  final String href;
  final String mediaType;
  final String properties;
  const _ManifestItem({required this.href, required this.mediaType, required this.properties});
}

class _BookReaderPageState extends State<BookReaderPage> {
  List<_Chapter> _chapters = [];
  int _currentChapter = 0;
  InAppWebViewController? _webController;
  bool _loading = true;
  String? _error;
  int _fontSize = 16;
  bool _isDarkMode = true;
  bool _showToolbar = true;
  double _lastScrollFraction = 0.0;

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.initialChapter;
    _extractAndParse();
  }

  @override
  void dispose() {
    _saveProgress();
    super.dispose();
  }

  void _saveProgress() {
    if (widget.bookResult == null || _chapters.isEmpty) return;
    BookProgressService.instance.saveProgress(
      book: widget.bookResult!,
      chapter: _currentChapter,
      scrollFraction: _lastScrollFraction,
      filePath: widget.file.path,
    );
  }

  String _dirName(String path) {
    final i = path.lastIndexOf('/');
    return i == -1 ? '' : path.substring(0, i);
  }

  Future<void> _extractAndParse() async {
    try {
      final bytes = await widget.file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final epubName = widget.file.path
          .replaceAll('\\', '/')
          .split('/')
          .last
          .replaceAll('.epub', '');
      final extractDir = Directory('${widget.file.parent.path}${Platform.pathSeparator}epub_$epubName');

      if (!extractDir.existsSync()) {
        extractDir.createSync(recursive: true);
        final extractRoot = extractDir.absolute.path;
        for (final entry in archive) {
          final entryName = entry.name.replaceAll('\\', '/');
          final targetPath = safeExtractPath(extractRoot, entryName);
          if (targetPath == null) continue;
          if (entryName.endsWith('/') || !entry.isFile) {
            Directory(targetPath).createSync(recursive: true);
            continue;
          }
          final f = File(targetPath);
          f.createSync(recursive: true);
          f.writeAsBytesSync(entry.content as List<int>);
        }
      }

      final containerFile = File('${extractDir.path}/META-INF/container.xml');
      if (!containerFile.existsSync()) {
        throw Exception('Invalid EPUB -- META-INF/container.xml missing');
      }
      final containerXml = XmlDocument.parse(await containerFile.readAsString());
      final opfPath = containerXml.findAllElements('rootfile').first.getAttribute('full-path')!;

      final opfFile = File('${extractDir.path}/$opfPath');
      final opfXml = XmlDocument.parse(await opfFile.readAsString());
      final opfDir = _dirName(opfPath);

      final manifestEl = opfXml.findAllElements('manifest').first;
      final manifest = <String, _ManifestItem>{};
      for (final el in manifestEl.findAllElements('item')) {
        final id = el.getAttribute('id');
        final href = el.getAttribute('href');
        if (id != null && href != null) {
          manifest[id] = _ManifestItem(
            href: href,
            mediaType: el.getAttribute('media-type') ?? '',
            properties: el.getAttribute('properties') ?? '',
          );
        }
      }

      final tocLabels = <String, String>{};
      final spineEl = opfXml.findAllElements('spine').first;

      final tocId = spineEl.getAttribute('toc');
      if (tocId != null && manifest.containsKey(tocId)) {
        final ncxHref = manifest[tocId]!.href;
        final ncxPath = opfDir.isEmpty ? ncxHref : '$opfDir/$ncxHref';
        final ncxFile = File('${extractDir.path}/$ncxPath');
        if (ncxFile.existsSync()) {
          try {
            final ncx = XmlDocument.parse(await ncxFile.readAsString());
            for (final np in ncx.findAllElements('navPoint')) {
              final label = np.findAllElements('text').firstOrNull?.innerText;
              final src = np.findAllElements('content').firstOrNull?.getAttribute('src');
              if (label != null && src != null) {
                final clean = src.contains('#') ? src.substring(0, src.indexOf('#')) : src;
                tocLabels.putIfAbsent(clean, () => label.trim());
              }
            }
          } catch (_) {}
        }
      }

      for (final item in manifest.values) {
        if (item.properties.contains('nav')) {
          final navPath = opfDir.isEmpty ? item.href : '$opfDir/${item.href}';
          final navFile = File('${extractDir.path}/$navPath');
          if (navFile.existsSync()) {
            try {
              final navHtml = await navFile.readAsString();
              final re = RegExp(r'<a[^>]+href="([^"]*)"[^>]*>(.*?)</a>', dotAll: true);
              for (final m in re.allMatches(navHtml)) {
                final href = m.group(1)!;
                final title = m.group(2)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
                final clean = href.contains('#') ? href.substring(0, href.indexOf('#')) : href;
                if (title.isNotEmpty) tocLabels.putIfAbsent(clean, () => title);
              }
            } catch (_) {}
          }
          break;
        }
      }

      final chapters = <_Chapter>[];
      for (final ref in spineEl.findAllElements('itemref')) {
        final idref = ref.getAttribute('idref')!;
        final item = manifest[idref];
        if (item == null) continue;
        if (!item.mediaType.contains('html') && !item.mediaType.contains('xml')) continue;

        final href = item.href;
        final fullPath = opfDir.isEmpty ? href : '$opfDir/$href';
        final filePath = '${extractDir.path}/$fullPath';
        final title = tocLabels[href] ?? tocLabels[fullPath] ?? '';
        chapters.add(_Chapter(
          filePath: filePath.replaceAll('\\', '/'),
          title: title.isNotEmpty ? title : 'Chapter ${chapters.length + 1}',
        ));
      }

      if (chapters.isEmpty) throw Exception('No readable chapters found');

      if (mounted) {
        setState(() {
          _chapters = chapters;
          _currentChapter = _currentChapter.clamp(0, chapters.length - 1);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _loadChapter(int index) {
    if (index < 0 || index >= _chapters.length || _webController == null) return;
    _saveProgress();
    setState(() {
      _currentChapter = index;
      _lastScrollFraction = 0.0;
    });
    final uri = Uri.file(_chapters[index].filePath, windows: Platform.isWindows);
    _webController!.loadUrl(urlRequest: URLRequest(url: WebUri(uri.toString())));
  }

  void _injectTheme() {
    final bg = _isDarkMode ? '#0B0B12' : '#ffffff';
    final fg = _isDarkMode ? '#e0e0e0' : '#1a1a1a';
    final link = _isDarkMode ? '#bb86fc' : '#6200ee';
    final border = _isDarkMode ? '#333' : '#ccc';

    _webController?.evaluateJavascript(source: '''
(function(){
  var s=document.getElementById('_rt');
  if(!s){s=document.createElement('style');s.id='_rt';document.head.appendChild(s);}
  s.textContent=
    'body,html{background:$bg!important;color:$fg!important;'
   +'font-size:${_fontSize}px!important;line-height:1.8!important;'
   +'padding:20px!important;margin:0!important;'
   +'font-family:Georgia,serif!important;'
   +'word-wrap:break-word!important;overflow-wrap:break-word!important}'
   +'*{color:inherit!important;border-color:$border!important}'
   +'a{color:$link!important}'
   +'img{max-width:100%!important;height:auto!important}'
   +'pre,code{white-space:pre-wrap!important}'
   +'table{max-width:100%!important}';
})();
''');

    _webController?.evaluateJavascript(source: '''
(function(){
  if(window._rtBound) return;
  window._rtBound=true;
  document.addEventListener('click',function(e){
    if(!e.target.closest('a')){
      window.flutter_inappwebview.callHandler('toggleBar');
    }
  });
})();
''');
  }

  void _showChapterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F121C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _chapters.length,
            itemBuilder: (context, index) {
              final isCurrent = index == _currentChapter;
              return ListTile(
                title: Text(
                  _chapters[index].title,
                  style: TextStyle(
                    color: isCurrent ? const Color(0xFF7C5CFF) : Colors.white,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _loadChapter(index);
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF080A0F),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7C5CFF))),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF080A0F),
        appBar: AppBar(backgroundColor: const Color(0xFF080A0F)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white38, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Could not open this book.\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final barBg = _isDarkMode ? const Color(0xFF0B0B12) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : Colors.black87;
    final subtextColor = _isDarkMode ? Colors.white54 : Colors.black54;
    final iconColor = _isDarkMode ? Colors.white70 : Colors.black87;

    return Scaffold(
      backgroundColor: barBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: InAppWebView(
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                transparentBackground: false,
                supportZoom: true,
                // Relative <img>/<link> references inside a chapter resolve
                // fine against the extracted folder via normal same-origin
                // file:// navigation -- these two flags are only needed for
                // JS-initiated fetch()/XHR to *other* file:// origins, which
                // this reader's injected JS never does. Left off since EPUBs
                // are untrusted third-party content and either flag would
                // let injected/malicious JS read arbitrary local files.
                allowFileAccessFromFileURLs: false,
                allowUniversalAccessFromFileURLs: false,
                verticalScrollBarEnabled: false,
                horizontalScrollBarEnabled: false,
                disableHorizontalScroll: true,
              ),
              onWebViewCreated: (controller) {
                _webController = controller;
                controller.addJavaScriptHandler(
                  handlerName: 'toggleBar',
                  callback: (_) {
                    if (mounted) setState(() => _showToolbar = !_showToolbar);
                  },
                );
                controller.addJavaScriptHandler(
                  handlerName: 'scrollProgress',
                  callback: (args) {
                    if (args.isNotEmpty) _lastScrollFraction = (args[0] as num).toDouble();
                  },
                );
                _loadChapter(_currentChapter);
              },
              onLoadStop: (controller, url) async {
                _injectTheme();
                controller.evaluateJavascript(source: '''
(function(){
  if(window._scrollBound) return;
  window._scrollBound=true;
  var t=null;
  window.addEventListener('scroll',function(){
    clearTimeout(t);
    t=setTimeout(function(){
      var h=Math.max(document.body.scrollHeight-window.innerHeight,1);
      var f=window.scrollY/h;
      window.flutter_inappwebview.callHandler('scrollProgress',f);
    },300);
  });
})();
''');
              },
            ),
          ),
          if (_showToolbar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [barBg.withValues(alpha: 0.97), barBg.withValues(alpha: 0.0)],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_rounded, color: iconColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_chapters.isNotEmpty)
                                Text(
                                  _chapters[_currentChapter].title,
                                  style: TextStyle(color: subtextColor, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(_isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: iconColor),
                          tooltip: _isDarkMode ? 'Light mode' : 'Dark mode',
                          onPressed: () {
                            setState(() => _isDarkMode = !_isDarkMode);
                            _injectTheme();
                          },
                        ),
                        if (_chapters.length > 1)
                          IconButton(
                            icon: Icon(Icons.list_rounded, color: iconColor),
                            tooltip: 'Chapters',
                            onPressed: _showChapterSheet,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_showToolbar)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [barBg.withValues(alpha: 0.97), barBg.withValues(alpha: 0.0)],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _pill(
                          icon: Icons.chevron_left_rounded,
                          iconColor: iconColor,
                          isDark: _isDarkMode,
                          onTap: _currentChapter > 0 ? () => _loadChapter(_currentChapter - 1) : null,
                        ),
                        const SizedBox(width: 12),
                        _pill(
                          icon: Icons.text_decrease_rounded,
                          iconColor: iconColor,
                          isDark: _isDarkMode,
                          onTap: _fontSize > 10
                              ? () {
                                  setState(() => _fontSize -= 2);
                                  _injectTheme();
                                }
                              : null,
                        ),
                        const SizedBox(width: 4),
                        Text('${_fontSize}px', style: TextStyle(color: subtextColor, fontSize: 11)),
                        const SizedBox(width: 4),
                        _pill(
                          icon: Icons.text_increase_rounded,
                          iconColor: iconColor,
                          isDark: _isDarkMode,
                          onTap: _fontSize < 56
                              ? () {
                                  setState(() => _fontSize += 2);
                                  _injectTheme();
                                }
                              : null,
                        ),
                        const SizedBox(width: 12),
                        _pill(
                          icon: Icons.chevron_right_rounded,
                          iconColor: iconColor,
                          isDark: _isDarkMode,
                          onTap: _currentChapter < _chapters.length - 1 ? () => _loadChapter(_currentChapter + 1) : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill({required IconData icon, required Color iconColor, required bool isDark, VoidCallback? onTap}) {
    return Material(
      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: onTap != null ? iconColor : iconColor.withValues(alpha: 0.3), size: 22),
        ),
      ),
    );
  }
}
