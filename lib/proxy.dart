//Copyright (C) 2018 Potix Corporation. All Rights Reserved.
//History: Thu Mar  8 12:52:15 CST 2018
// Author: tomyeh
library stream_proxy;

import "dart:async";
import "dart:io";

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import "stream.dart";

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
/// * [shallRetry] a callback to return true if [proxyRequest] shall
/// retry to connect [url].
Future proxyRequest(HttpConnect connect, url, {String proxyName,
      FutureOr<bool> shallRetry(ex, StackTrace st)}) async {
  //COPRYRIGHT NOTICE:
  //The code is ported from [shelf_proxy](https://github.com/dart-lang/shelf_proxy)

  Uri uri;
  if (url is String) {
    uri = Uri.parse(url);
  } else if (url is Uri) {
    uri = url;
  } else {
    throw new ArgumentError.value(url, 'url', 'url must be a String or Uri.');
  }

  final client = new http.Client(),
    serverRequest = connect.request,
    serverResponse = connect.response;
  var clientResponse;

  for (List<int> requestBody;;) {
    try {
      var clientRequest =
          new http.StreamedRequest(serverRequest.method, uri);
      clientRequest.followRedirects = false;
      serverRequest.headers.forEach((String name, List<String> values) {
        for (final value in values)
          _addHeader(clientRequest.headers, name, value);
      });
      clientRequest.headers['Host'] = uri.authority;

      // Add a Via header. See
      // http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.45
      _addHeader(clientRequest.headers, 'via',
          '${serverRequest.protocolVersion} ${proxyName??"Stream"}');

      if (requestBody == null) { //first time
        var onAdd;
        if (shallRetry != null) {
          requestBody = <int>[];
          onAdd = (List<int> event) {
            requestBody.addAll(event);
          };
        }

        await _store(serverRequest, clientRequest.sink, onAdd: onAdd);
      } else { //retries
        clientRequest.sink.add(requestBody);
      }

      clientResponse = await client.send(clientRequest);
      break; //done

    } on SocketException catch (ex, st) {
      if (shallRetry == null || (await shallRetry(ex, st)) != true)
        rethrow;
      //retry
    }
  }

  serverResponse.statusCode = clientResponse.statusCode;
  clientResponse.headers.forEach((name, value) {
    serverResponse.headers.add(name, value);
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
    serverResponse.headers.removeAll(HttpHeaders.CONTENT_ENCODING);
    serverResponse.headers.removeAll(HttpHeaders.CONTENT_LENGTH);

    // Add a Warning header. See
    // http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.5.2
    serverResponse.headers.add('warning', '214 ${proxyName??'Stream'} "GZIP decoded"');
  }

  // Make sure the Location header is pointing to the proxy server rather
  // than the destination server, if possible.
  if (clientResponse.isRedirect
  && clientResponse.headers.containsKey('location')) {
    var location =
        uri.resolve(clientResponse.headers['location']).toString();
    if (p.url.isWithin(uri.toString(), location)) {
      serverResponse.headers.set('location',
          '/' + p.url.relative(location, from: uri.toString()));
    } else {
      serverResponse.headers.set('location', location);
    }
  }

  await _store(clientResponse.stream, serverResponse);
}

void _addHeader(Map<String, String> headers, String name, String value) {
  if (headers.containsKey(name)) {
    headers[name] += ', $value';
  } else {
    headers[name] = value;
  }
}

Future _store<T>(Stream<T> stream, EventSink<T> sink,
    {bool cancelOnError: true, bool closeSink: true, void onAdd(T event)}) {
  var completer = new Completer();
  stream.listen(onAdd == null ? sink.add: (event) {
    onAdd(event);
    sink.add(event);
  }, onError: (e, stackTrace) {
    sink.addError(e, stackTrace);
    if (cancelOnError) {
      completer.complete();
      if (closeSink) sink.close();
    }
  }, onDone: () {
    if (closeSink) sink.close();
    completer.complete();
  }, cancelOnError: cancelOnError);
  return completer.future;
}
