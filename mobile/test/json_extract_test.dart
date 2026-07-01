import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hivedownload/models/series.dart';
import 'package:hivedownload/services/json_extract.dart';

void main() {
  group('JsonExtract.balancedAfter', () {
    test('pulls a balanced array out of embedded JS', () {
      const html = 'var x=1; seriesData = [{"id":1,"t":"a"},{"id":2}]; more();';
      final out = JsonExtract.catalogArray(html);
      expect(out, '[{"id":1,"t":"a"},{"id":2}]');
      expect(jsonDecode(out!), isA<List>());
    });

    test('is not fooled by brackets inside strings (Thai descriptions)', () {
      const html = 'seriesData = [{"desc":"ตอน [1] (พิเศษ]"}] ;';
      final out = JsonExtract.catalogArray(html);
      expect(jsonDecode(out!), isA<List>());
      expect((jsonDecode(out) as List).first['desc'], 'ตอน [1] (พิเศษ]');
    });

    test('extracts the episodes array from a watch page', () {
      const html = '{"episodes_count":3,"episodes":[{"episode_number":1},{"episode_number":2}]}';
      final out = JsonExtract.episodesArray(html);
      expect(out, '[{"episode_number":1},{"episode_number":2}]');
    });

    test('returns null when unbalanced or absent', () {
      expect(JsonExtract.catalogArray('seriesData = [1,2,3'), isNull);
      expect(JsonExtract.catalogArray('nothing here'), isNull);
    });
  });

  group('Series.fromJson', () {
    test('parses id/title and derives clean title + dub + year from poster', () {
      final s = Series.fromJson({
        'id': 42,
        'title': 'บ่วงรักth',
        'description': 'เรื่องย่อ',
        'poster_url': 'uploads/poster/บ่วงรัก-พากย์ไทย-2026-42.webp',
        'jpg_url': 'uploads/poster/บ่วงรัก-พากย์ไทย-2026-42.jpg',
        'view_count': 15200,
      });
      expect(s, isNotNull);
      expect(s!.id, 42);
      expect(s.cleanTitle, 'บ่วงรัก');
      expect(s.typeThai, 'พากย์ไทย');
      expect(s.year, 2026);
      expect(s.posterUrl, startsWith('https://rongyok.com/'));
      expect(s.viewCountText, '15.2K');
    });

    test('falls back to trimming trailing "th" when poster has no pattern', () {
      final s = Series.fromJson({'id': 7, 'title': 'รักลวงth', 'poster_url': ''});
      expect(s!.cleanTitle, 'รักลวง');
    });

    test('returns null without a numeric id', () {
      expect(Series.fromJson({'title': 'x'}), isNull);
    });
  });
}
