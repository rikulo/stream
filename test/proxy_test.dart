//Copyright (C) 2026 Potix Corporation. All Rights Reserved.
import 'dart:async';
import 'package:test/test.dart';
import 'package:stream/proxy.dart';

void main() {
  group('copyToSink', () {
    test('copies all events from stream to sink', () async {
      final src = Stream.fromIterable([1, 2, 3]);
      final sink = _RecordingSink<int>();

      await copyToSink(src, sink);

      expect(sink.events, [1, 2, 3]);
      expect(sink.closed, isTrue);
    });

    test('completes immediately for an empty stream', () async {
      final src = Stream<int>.empty();
      final sink = _RecordingSink<int>();

      await copyToSink(src, sink);

      expect(sink.events, isEmpty);
      expect(sink.closed, isTrue);
    });

    test('closeSink: false leaves sink open', () async {
      final src = Stream.fromIterable([1, 2]);
      final sink = _RecordingSink<int>();

      await copyToSink(src, sink, closeSink: false);

      expect(sink.events, [1, 2]);
      expect(sink.closed, isFalse);
    });

    test('forwards errors to sink and completes successfully', () async {
      final ctrl = StreamController<int>();
      final sink = _RecordingSink<int>();

      final done = copyToSink(ctrl.stream, sink);

      ctrl.add(1);
      ctrl.addError('boom', StackTrace.current);
      // cancelOnError=true (default) → subscription cancels after error,
      // so the stream is effectively done at this point.

      await done; // must not throw
      expect(sink.events, [1]);
      expect(sink.errors.length, 1);
      expect(sink.errors.first, 'boom');
      expect(sink.closed, isTrue);

      await ctrl.close();
    });

    test('cancelOnError: false keeps reading after an error', () async {
      final ctrl = StreamController<int>();
      final sink = _RecordingSink<int>();

      final done = copyToSink(ctrl.stream, sink, cancelOnError: false);

      ctrl.add(1);
      ctrl.addError('boom1');
      ctrl.add(2);
      ctrl.addError('boom2');
      ctrl.add(3);
      await ctrl.close();

      await done;
      expect(sink.events, [1, 2, 3]);
      expect(sink.errors, ['boom1', 'boom2']);
      expect(sink.closed, isTrue);
    });

    test('copyTo intercepts events instead of forwarding to sink', () async {
      final src = Stream.fromIterable([1, 2, 3]);
      final sink = _RecordingSink<int>();
      final intercepted = <int>[];

      await copyToSink<int>(src, sink, copyTo: (event, _) {
        intercepted.add(event);
      });

      expect(intercepted, [1, 2, 3]);
      // copyTo replaces sink.add — the recording sink never sees data events.
      expect(sink.events, isEmpty);
      expect(sink.closed, isTrue);
    });

    test('copyTo can request early close via its callback', () async {
      final ctrl = StreamController<int>();
      final sink = _RecordingSink<int>();
      final intercepted = <int>[];

      final done = copyToSink<int>(ctrl.stream, sink, copyTo: (event, close) {
        intercepted.add(event);
        if (event == 2) close();
      });

      ctrl.add(1);
      ctrl.add(2);
      // Once close() runs, the completer completes and sink is closed.
      await done;
      expect(intercepted, contains(1));
      expect(intercepted, contains(2));
      expect(sink.closed, isTrue);

      // Cleanup any remaining items.
      await ctrl.close();
    });
  });
}

class _RecordingSink<T> implements EventSink<T> {
  final List<T> events = [];
  final List<Object> errors = [];
  bool closed = false;

  @override
  void add(T event) {
    events.add(event);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    errors.add(error);
  }

  @override
  void close() {
    closed = true;
  }
}
