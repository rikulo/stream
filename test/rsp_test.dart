//Copyright (C) 2026 Potix Corporation. All Rights Reserved.
import 'package:test/test.dart';
import 'package:stream/stream.dart';

void main() {
  group('Rsp.isHeaderValueValid', () {
    test('accepts ASCII printable and tab', () {
      expect(Rsp.isHeaderValueValid('Hello, World!'), isTrue);
      expect(Rsp.isHeaderValueValid('a\tb'), isTrue);
      expect(Rsp.isHeaderValueValid(''), isTrue);
      expect(Rsp.isHeaderValueValid(' '), isTrue);
      expect(Rsp.isHeaderValueValid('~'), isTrue);
    });
    test('rejects control chars (CR/LF/NUL) and non-ASCII', () {
      expect(Rsp.isHeaderValueValid('a\nb'), isFalse);
      expect(Rsp.isHeaderValueValid('a\rb'), isFalse);
      expect(Rsp.isHeaderValueValid('\x00'), isFalse);
      expect(Rsp.isHeaderValueValid('\x1f'), isFalse);
      expect(Rsp.isHeaderValueValid('café'), isFalse);
      expect(Rsp.isHeaderValueValid(''), isFalse);
    });
  });

  group('Rsp.nns', () {
    test('returns empty for null', () {
      expect(Rsp.nns(), '');
      expect(Rsp.nns(null), '');
    });
    test('uses toString otherwise', () {
      expect(Rsp.nns(0), '0');
      expect(Rsp.nns(false), 'false');
      expect(Rsp.nns('hi'), 'hi');
      expect(Rsp.nns([1, 2]), '[1, 2]');
    });
  });

  group('Rsp.nnx', () {
    test('default xml/html encoding', () {
      expect(Rsp.nnx('<a>'), '&lt;a&gt;');
      expect(Rsp.nnx('"&'), '&quot;&amp;');
    });
    test('encode=none returns raw', () {
      expect(Rsp.nnx('<a>', encode: 'none'), '<a>');
    });
    test('encode=json serializes', () {
      expect(Rsp.nnx({'k': 'v'}, encode: 'json'), '{"k":"v"}');
      expect(Rsp.nnx([1, 2], encode: 'json'), '[1,2]');
    });
    test('encode=query percent-encodes', () {
      expect(Rsp.nnx('a b&c', encode: 'query'), 'a+b%26c');
    });
    test('null returns empty', () {
      expect(Rsp.nnx(null), '');
      expect(Rsp.nnx(null, encode: 'none'), '');
    });

    group('maxLength (regression: condition was `>` instead of `<`)', () {
      test('truncates with ellipsis when shorter than full', () {
        expect(Rsp.nnx('Hello, World!', encode: 'none', maxLength: 10),
            'Hello, ...');
      });
      test('does not truncate when at or below maxLength', () {
        expect(Rsp.nnx('Hello', encode: 'none', maxLength: 10), 'Hello');
        expect(Rsp.nnx('Hello', encode: 'none', maxLength: 5), 'Hello');
      });
      test('returns only ellipsis when maxLength < 3', () {
        expect(Rsp.nnx('Hello', encode: 'none', maxLength: 1), '...');
        expect(Rsp.nnx('Hello', encode: 'none', maxLength: 2), '...');
      });
      test('maxLength=0 means no truncation', () {
        expect(Rsp.nnx('Hello, World!', encode: 'none'), 'Hello, World!');
      });
      test('does not throw RangeError when shorter than maxLength', () {
        // The old condition `maxLength > str.length` triggered `substring(0, maxLength - 3)`
        // even when the string was shorter, causing a RangeError.
        expect(() => Rsp.nnx('Hi', encode: 'none', maxLength: 100),
            returnsNormally);
        expect(Rsp.nnx('Hi', encode: 'none', maxLength: 100), 'Hi');
      });
    });

    group('firstLine', () {
      test('returns the first non-empty line', () {
        expect(Rsp.nnx('first\nsecond', encode: 'none', firstLine: true),
            'first');
      });
      test('skips leading empty lines', () {
        expect(Rsp.nnx('\n\nfirst', encode: 'none', firstLine: true),
            'first');
      });
      test('returns empty for all-empty input', () {
        expect(Rsp.nnx('\n\n\n', encode: 'none', firstLine: true), '');
        expect(Rsp.nnx('', encode: 'none', firstLine: true), '');
      });
      test('combines with maxLength', () {
        expect(
            Rsp.nnx('long first line\nshort',
                encode: 'none', firstLine: true, maxLength: 5),
            'lo...');
      });
    });
  });

  group('Rsp.cat', () {
    test('returns uri unchanged if no parameters', () {
      expect(Rsp.cat('/foo', null), '/foo');
      expect(Rsp.cat('/foo', {}), '/foo');
    });
    test('appends `?key=value` when uri has no query', () {
      expect(Rsp.cat('/foo', {'a': '1'}), '/foo?a=1');
    });
    test('appends `&key=value` when uri already has a query', () {
      expect(Rsp.cat('/foo?x=y', {'a': '1'}), '/foo?x=y&a=1');
    });
    test('handles multiple parameters', () {
      final out = Rsp.cat('/foo', {'a': '1', 'b': '2'});
      expect(out, anyOf('/foo?a=1&b=2', '/foo?b=2&a=1'));
    });
  });

  group('Rsp.json', () {
    test('escapes </script> to <\\/script>', () {
      expect(Rsp.json('</script>'), r'"<\/script>"');
    });
    test('case-insensitive </SCRIPT>', () {
      expect(Rsp.json('</SCRIPT>'), r'"<\/SCRIPT>"');
    });
    test('does not escape </span>', () {
      expect(Rsp.json('</span>'), '"</span>"');
    });
    test('encodes maps and lists', () {
      expect(Rsp.json({'k': 'v'}), '{"k":"v"}');
      expect(Rsp.json([1, 'x', null]), '[1,"x",null]');
    });
    test('handles embedded quotes', () {
      expect(Rsp.json('a"b'), r'"a\"b"');
    });
  });

  group('HttpStatusException', () {
    test('carries the right status code', () {
      expect(HttpStatusException(404).statusCode, 404);
      expect(Http400().statusCode, 400);
      expect(Http401().statusCode, 401);
      expect(Http403().statusCode, 403);
      expect(Http404().statusCode, 404);
      expect(Http500().statusCode, 500);
      expect(Http503().statusCode, 503);
    });
    test('toString includes status code', () {
      expect(HttpStatusException(404, message: 'Not Found').toString(),
          contains('404'));
      expect(HttpStatusException(404, message: 'Not Found').toString(),
          contains('Not Found'));
    });
    test('toString includes uri when given', () {
      final ex = HttpStatusException(404,
          uri: Uri.parse('https://example.com/missing'),
          message: 'gone');
      final s = ex.toString();
      expect(s, contains('404'));
      expect(s, contains('uri='));
      expect(s, contains('example.com'));
    });
    test('Http5xx with cause embeds the cause in the message', () {
      expect(Http500(cause: 'db down').message, contains('db down'));
      expect(Http503(cause: 'overload').message, contains('overload'));
    });
    test('default message is the status code string', () {
      expect(HttpStatusException(418).message, '418');
    });
  });
}
