//Copyright (C) 2018 Potix Corporation. All Rights Reserved.
//History: Thu Mar  8 12:52:15 CST 2018
// Author: tomyeh
library stream_proxy;

import "dart:async";
import "dart:io";
import "dart:convert";

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import "package:logging/logging.dart" show Logger;
import 'package:rikulo_commons/util.dart';

import "stream.dart";

final _logger = Logger('stream.proxy');

/// Proxies the request of [url] to [connect].
///
/// Example:
///
///     Future proxyFoo(HttpConnect connect)
///     => proxy(connect, getTargetUrl(connect));
///
/// * [url] must be a [String] or [Uri].
/// * [proxyName] is used in headers to identify this proxy. It should be a valid
/// HTTP token or a hostname. It defaults to null -- no `via` header will be added.
/// * [shallRetry] a callback to decide whether to retry when
/// [proxyRequest] receives an exception.
/// Ignored if omitted.
/// * [onStatusCode] if specified, it'll be called with the status code
/// received.
/// * [log] If specified, it'll be called if there is an ignorable error,
/// e.g., header's value containing invalid characters
Future proxyRequest(HttpConnect connect, url, {String? proxyName,
      FutureOr<bool> shallRetry(Object ex, StackTrace st)?,
      void onStatusCode(int code)?,
      void log(String errmsg)?}) async {
  //COPRYRIGHT NOTICE:
  //The code is ported from [shelf_proxy](https://github.com/dart-lang/shelf_proxy)

  Uri uri;
  if (url is String) {
    uri = Uri.parse(url);
  } else if (url is Uri) {
    uri = url;
  } else {
    throw ArgumentError.value(url, 'url', 'url must be a String or Uri.');
  }

  final client = http.Client(),
    serverRequest = connect.request,
    serverResponse = connect.response;
  http.StreamedResponse clientResponse;

  for (List<int>? requestBody;;) {
    try {
      final clientRequest = http.StreamedRequest(serverRequest.method, uri);
      clientRequest.followRedirects = false;
      serverRequest.headers.forEach((name, values) {
        for (final value in values)
          if (Rsp.isHeaderValueValid(value))
            _addHeader(clientRequest.headers, name, value);
          else
            (log ?? _logger.warning)('Ignored: invalid request header value: $name=${json.encode(value)}');
      });
      clientRequest.headers['Host'] = uri.authority;

      // Add a Via header. See
      // http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.45
      _addHeader(clientRequest.headers, 'via',
          '${serverRequest.protocolVersion} ${proxyName??"Stream"}');

      if (requestBody == null) { //first time
        _CopyTo<List<int>>? copyTo;
        if (shallRetry != null) {
          final body = requestBody = <int>[];
          copyTo = (List<int> event, void close()) {
            body.addAll(event);
            clientRequest.sink.add(event);
          };
        }

        await copyToSink(serverRequest, clientRequest.sink, copyTo: copyTo);
      } else { //retries
        clientRequest.sink.add(requestBody);
      }

      clientResponse = await client.send(clientRequest);
      break; //done

    } catch (ex, st) {
      if (shallRetry == null || (await shallRetry(ex, st)) != true)
        rethrow;
      //retry
    }
  }

  final code = serverResponse.statusCode = clientResponse.statusCode;
  onStatusCode?.call(code);

  clientResponse.headers.forEach((name, value) {
    if (!Rsp.isHeaderValueValid(value)) {
      var fixed = false;
      if (name.toLowerCase() == 'content-disposition') {
        value = value.replaceAllMapped(
            RegExp(r'(name=")([^"]+)(")'),
            (m) => '${m[1]}${Uri.encodeComponent(m[2]!)}${m[3]}');
        fixed = Rsp.isHeaderValueValid(value);
      }

      if (!fixed) {
        (log ?? _logger.warning)('Ignored: invalid response header value: $name=${json.encode(value)}');
        return; //skip
      }
    }

    serverResponse.headers.add(name, value, preserveHeaderCase: true);
  });

  // Add a Via header. See
  // http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.45
  if (proxyName != null)
    serverResponse.headers.add('via', '1.1 $proxyName');

  // Remove the transfer-encoding since the body has already been decoded by
  // [client].
  serverResponse.headers.removeAll('transfer-encoding');

  // If the original response was gzipped, it will be decoded by [client]
  // and we'll have no way of knowing its actual content-length.
  if (clientResponse.headers['content-encoding'] == 'gzip') {
    serverResponse.headers
      ..removeAll(HttpHeaders.contentEncodingHeader)
      ..removeAll(HttpHeaders.contentLengthHeader);

    // Add a Warning header. See
    // http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.5.2
    serverResponse.headers.add('warning', '214 ${proxyName??'Stream'} "GZIP decoded"');
  }

  // Make sure the Location header is pointing to the proxy server rather
  // than the destination server, if possible.
  if (clientResponse.isRedirect) {
    final rawLocation = clientResponse.headers['location'];
    if (rawLocation != null) {
      var location = uri.resolve(rawLocation).toString();
      if (p.url.isWithin(uri.toString(), location)) {
        serverResponse.headers.set('location',
            '/' + p.url.relative(location, from: uri.toString()));
      } else {
        serverResponse.headers.set('location', location);
      }
    }
  }

  await copyToSink(clientResponse.stream, serverResponse);
}

void _addHeader(Map<String, String> headers, String name, String value) {
  if (headers.containsKey(name)) {
    headers[name] = '${headers[name]}, $value';
  } else {
    headers[name] = value;
  }
}

/// Copies [stream] into [sink].
///
/// - [copyTo] if specified, it is called instead of [sink.add].
/// The implementation can call `close()` if it'd like to stop
/// the reading.
Future copyToSink<T>(Stream<T> stream, EventSink<T> sink,
    {bool cancelOnError = true, bool closeSink = true,
     void copyTo(T event, void close())?}) {
  final c = Completer();

  var done = false;
  void setDone() {
    if (!done) {
      done = true;
      if (!c.isCompleted) c.complete();
      if (closeSink) InvokeUtil.invokeSafely(sink.close);
    }
  }

  late final StreamSubscription<T> sub;
  sub = stream.listen(
    copyTo == null ? sink.add: (data) => copyTo(data, setDone),
    onError: (Object e, StackTrace st) {
      if (!done) {
        sink.addError(e, st);
        if (cancelOnError) {
          if (!c.isCompleted) c.complete();
          if (closeSink) InvokeUtil.invokeSafely(sink.close);
          InvokeUtil.invokeSafely(sub.cancel);
        }
      }
    },
    onDone: setDone,
    cancelOnError: cancelOnError);

  return c.future;
}
typedef void _CopyTo<T>(T event, void close());
