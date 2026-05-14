//Copyright (C) 2026 Potix Corporation. All Rights Reserved.
import 'dart:io';
import 'package:test/test.dart';
import 'package:stream/plugin.dart';

const _size = 1000;
final _modified = DateTime.utc(2026, 1, 1, 12, 0, 0);
const _etag = '"abc123"';

RangeParseResult _parse(String? range,
        {String? ifRange,
         DateTime? lastModified,
         String? etag = _etag,
         int assetSize = _size}) =>
    parseRangeHeaders(
        range, ifRange, lastModified ?? _modified, etag, assetSize);

void main() {
  group('parseRangeHeaders — Range header', () {
    test('no Range header → serve whole asset', () {
      final r = _parse(null);
      expect(r.ranges, isNull);
      expect(r.errorStatus, isNull);
    });

    test('bytes=0-99 → first 100 bytes', () {
      final r = _parse('bytes=0-99');
      expect(r.errorStatus, isNull);
      expect(r.ranges, [(start: 0, end: 100, length: 100)]);
    });

    test('bytes=100- → from 100 to end', () {
      final r = _parse('bytes=100-');
      expect(r.errorStatus, isNull);
      expect(r.ranges, [(start: 100, end: _size, length: 900)]);
    });

    test('bytes=-100 → last 100 bytes (suffix)', () {
      final r = _parse('bytes=-100');
      expect(r.errorStatus, isNull);
      expect(r.ranges, [(start: _size - 100, end: _size, length: 100)]);
    });

    test('bytes=-N where N ≥ assetSize → whole asset (RFC 7233 §2.1)', () {
      final r = _parse('bytes=-99999');
      expect(r.errorStatus, isNull);
      expect(r.ranges, [(start: 0, end: _size, length: _size)]);
    });

    test('bytes=-0 → 416 Range Not Satisfiable (RFC 7233 §2.1)', () {
      final r = _parse('bytes=-0');
      expect(r.errorStatus, HttpStatus.requestedRangeNotSatisfiable);
      expect(r.indicateAssetSize, isTrue);
      expect(r.ranges, isNull);
    });

    test('bytes=- → 400 Bad Request', () {
      final r = _parse('bytes=-');
      expect(r.errorStatus, HttpStatus.badRequest);
      expect(r.ranges, isNull);
    });

    test('range past end → 416', () {
      final r = _parse('bytes=10000-20000');
      expect(r.errorStatus, HttpStatus.requestedRangeNotSatisfiable);
      expect(r.indicateAssetSize, isTrue);
    });

    test('multi-range bytes=0-99,200-299', () {
      final r = _parse('bytes=0-99,200-299');
      expect(r.errorStatus, isNull);
      expect(r.ranges, [
        (start: 0, end: 100, length: 100),
        (start: 200, end: 300, length: 100),
      ]);
    });

    test('multi-range tolerates OWS after commas', () {
      final r = _parse('bytes=0-99, 200-299, 400-499');
      expect(r.errorStatus, isNull);
      expect(r.ranges?.length, 3);
    });

    test('malformed foo-bar → 400', () {
      expect(_parse('bytes=foo-bar').errorStatus, HttpStatus.badRequest);
    });

    test('malformed 100-foo → 400', () {
      expect(_parse('bytes=100-foo').errorStatus, HttpStatus.badRequest);
    });

    test('unit other than bytes → 400', () {
      expect(_parse('items=0-9').errorStatus, HttpStatus.badRequest);
    });

    test('trailing comma is rejected', () {
      expect(_parse('bytes=0-99,').errorStatus, HttpStatus.badRequest);
    });
  });

  group('parseRangeHeaders — If-Range', () {
    test('matching strong etag → ranges parsed', () {
      final r = _parse('bytes=0-9', ifRange: _etag);
      expect(r.errorStatus, isNull);
      expect(r.ranges?.length, 1);
    });

    test('mismatched etag → serve whole (dirty)', () {
      final r = _parse('bytes=0-9', ifRange: '"different"');
      expect(r.ranges, isNull);
      expect(r.errorStatus, isNull);
    });

    test('client-side weak etag never matches (RFC 7232 §2.3.2)', () {
      final r = _parse('bytes=0-9', ifRange: 'W/$_etag');
      expect(r.ranges, isNull);
      expect(r.errorStatus, isNull);
    });

    test('server-side weak etag never matches', () {
      final r = _parse('bytes=0-9', ifRange: 'W/"x"', etag: 'W/"x"');
      expect(r.ranges, isNull);
      expect(r.errorStatus, isNull);
    });

    test('If-Range with HTTP-date matching lastModified → ranges parsed', () {
      final ifRange = HttpDate.format(_modified);
      final r = _parse('bytes=0-9', ifRange: ifRange);
      expect(r.errorStatus, isNull);
      expect(r.ranges?.length, 1);
    });

    test('If-Range with HTTP-date older than lastModified → serve whole', () {
      final older = _modified.subtract(const Duration(days: 7));
      final r = _parse('bytes=0-9', ifRange: HttpDate.format(older));
      expect(r.ranges, isNull);
      expect(r.errorStatus, isNull);
    });

    test('If-Range with no Range header → serve whole', () {
      final r = _parse(null, ifRange: _etag);
      expect(r.ranges, isNull);
      expect(r.errorStatus, isNull);
    });

    test('If-Range unparseable as date falls through to etag compare', () {
      //"garbage" is neither a date nor a matching etag → dirty
      final r = _parse('bytes=0-9', ifRange: 'garbage');
      expect(r.ranges, isNull);
      expect(r.errorStatus, isNull);
    });
  });
}
