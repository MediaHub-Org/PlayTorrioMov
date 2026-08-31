import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:playtorrio/pages/read/book_reader_page.dart';

void main() {
  group('safeExtractPath (Zip Slip guard)', () {
    final root = p.normalize('/tmp/epub_extract');

    test('accepts a normal relative entry', () {
      expect(safeExtractPath(root, 'OEBPS/chapter1.xhtml'), p.join(root, 'OEBPS', 'chapter1.xhtml'));
    });

    test('accepts nested directories', () {
      expect(safeExtractPath(root, 'OEBPS/images/cover.jpg'), p.join(root, 'OEBPS', 'images', 'cover.jpg'));
    });

    test('rejects a parent-traversal entry', () {
      expect(safeExtractPath(root, '../../evil.sh'), isNull);
    });

    test('rejects a traversal entry that dips out and back in', () {
      expect(safeExtractPath(root, 'OEBPS/../../../evil.sh'), isNull);
    });

    test('rejects an absolute path baked into the entry name', () {
      expect(safeExtractPath(root, '/etc/passwd'), isNull);
    });

    test('accepts the root itself (a bare directory entry)', () {
      expect(safeExtractPath(root, '.'), root);
    });
  });
}
