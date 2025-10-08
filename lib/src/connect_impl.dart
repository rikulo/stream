//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Fri, Jan 18, 2013  9:26:05 AM
// Author: tomyeh
part of stream;

///The implementation of channel.
class _HttpChannel implements HttpChannel {
  @override
  final HttpServer httpServer;
  @override
  final StreamServer server;
  @override
  final DateTime startedSince;

  bool _closed = false;

  _HttpChannel(this.server, this.httpServer, this.address, this.port,
      this.isSecure): startedSince = DateTime.now(), socket = null;
  _HttpChannel.fromSocket(this.server, this.httpServer, ServerSocket socket):
    startedSince = DateTime.now(), this.socket = socket,
    isSecure = socket is SecureServerSocket,
    address = null, port = socket.port;

  @override
  HttpConnectionsInfo get connectionsInfo => httpServer.connectionsInfo();
  @override
  Future close() {
    _closed = true;

    final List<HttpChannel> channels = server.channels;
    //reverse order, since [StreamServer.stop] handles it this way
    for (int i = channels.length; --i >= 0;)
      if (identical(this, channels[i])) {
        channels.removeAt(i);
        break;
      }

    return httpServer.close();
  }
  @override
  bool get isClosed => _closed;

  @override
  final ServerSocket? socket;
  @override
  final address;
  @override
  final int port;
  @override
  final bool isSecure;
}

///Skeletal implementation
abstract class _AbstractConnect implements HttpConnect {
  Browser? _browser;
  List<String>? _locales;

  _AbstractConnect(this.request, this.response);

  @override
  final HttpRequest request;
  @override
  final HttpResponse response;

  @override
  Browser get browser
  => _browser ??= _Browser(headerValue(HttpHeaders.userAgentHeader) ?? "");

  @override
  String? headerValue(String name) => request.headers[name]?.first;
  @override
  DateTime? get ifModifiedSince {
    try {
      return request.headers.ifModifiedSince;
    } catch (_) {
    }
  }

  @override
  String get locale {
    final ls = locales;
    return ls.isEmpty ? "en_US": ls.first;
  }
  @override
  List<String> get locales {
    var locales = _locales;
    if (locales == null) {
      locales = _locales = [];
      final langs = request.headers[HttpHeaders.acceptLanguageHeader];
      if (langs != null) {
        final infos = HashMap<num, List<String>>();
        for (final lang in langs) {
          _parseLocales(lang, infos);
        }

        if (infos.isNotEmpty) {
          final qs = List.from(infos.keys)..sort();
          for (int i = qs.length; --i >= 0;) //higher quality first
            locales.addAll(infos[qs[i]]!);
        }
      }
    }
    return locales;
  }

  @override
  void redirect(String uri, {int status = HttpStatus.movedTemporarily}) {
    response.statusCode = status;
    response.headers.set(HttpHeaders.locationHeader, _toCompleteUrl(request, uri));
  }
  @override
  Future forward(String uri, {HttpRequest? request, HttpResponse? response})
  => server.forward(this, uri, request: request, response: response);
  @override
  Future include(String uri, {HttpRequest? request, HttpResponse? response})
  => server.include(this, uri, request: request, response: response);
}

///The default implementation of HttpConnect
class _HttpConnect extends _AbstractConnect {
  _HttpConnect(this.channel, HttpRequest request, HttpResponse response):
      super(request, response);

  @override
  StreamServer get server => channel.server;
  @override
  final HttpChannel channel;

  @override
  String? language;
  @override
  bool autoClose = true;

  @override
  HttpConnect? get forwarder => null;
  @override
  HttpConnect? get includer => null;
  @override
  bool get isIncluded => false;
  @override
  bool get isForwarded => false;

  @override
  ErrorDetail? errorDetail;

  @override
  Map<String, dynamic> get dataset
  => _dataset ??= MapUtil.auto(() => _dataset = HashMap<String, dynamic>());
  Map<String, dynamic>? _dataset;
}

//Parse Accept-Language into locales
void _parseLocales(String lang, Map<num, List<String>> infos) {
  for (int i = 0;;) {
    final int j = lang.indexOf(',', i);
    final String val = j >= 0 ? lang.substring(i, j): lang.substring(i);
    int k = val.indexOf(';');
    final String locale =
      (k >= 0 ? val.substring(0, k): val).trim().replaceAll('-', '_');

    num quality = 1;
    if (k >= 0) {
      k = val.indexOf('=', k + 1);
      if (k >= 0) {
        try {
          quality = double.parse(val.substring(k + 1).trim());
        } catch (e) { //ignore silently
        }
      }
    }

    var locales = infos[quality];
    if (locales == null)
      infos[quality] = locales = [];
    locales.add(locale);

    if (j < 0)
      break;
    i = j + 1;
  }
}

///Used to implement forwarder and includer.
/// 
/// Unlike [HttpConnectWrapper], it retrieves headers from the given [request],
/// rather than from [origin]. Examples, [headerValue] and [locale].
class _ProxyConnect extends _AbstractConnect {
  final HttpConnect origin;

  _ProxyConnect(HttpConnect origin, HttpRequest request, HttpResponse response):
      origin = origin, super(request, response);

  @override
  StreamServer get server => origin.server;
  @override
  HttpChannel get channel => origin.channel;

  @override
  String? get language => origin.language;
  @override
  void set language(String? language) {
    origin.language = language;
  }

  @override
  bool get autoClose => origin.autoClose;
  @override
  void set autoClose(bool auto) {
    origin.autoClose = auto;
  }

  @override
  HttpConnect? get forwarder => origin.forwarder;
  @override
  HttpConnect? get includer => origin.includer;
  @override
  bool get isIncluded => origin.isIncluded;
  @override
  bool get isForwarded => origin.isForwarded;

  @override
  ErrorDetail? get errorDetail => origin.errorDetail;
  @override
  void set errorDetail(ErrorDetail? errorDetail) {
    origin.errorDetail = errorDetail;
  }

  @override
  Map<String, dynamic> get dataset => origin.dataset;
}

class _BufferedConnect extends _ProxyConnect {
  _BufferedConnect(HttpConnect connect, List<int> buffer):
    super(connect, connect.request,
        BufferedResponse(connect.response, buffer));
}
class _StringBufferedConnect extends _ProxyConnect {
  _StringBufferedConnect(HttpConnect connect, StringBuffer buffer):
    super(connect, connect.request,
        StringBufferedResponse(connect.response, buffer));
}

///HttpConnect for forwarded request
class _ForwardedConnect extends _ProxyConnect {
  ///[uri]: if null, it means no need to change
  _ForwardedConnect(HttpConnect connect, HttpRequest? request,
    HttpResponse? response, String? uri):
    super(connect,
      _wrapRequest(request != null ? request: connect.request, uri),
      _wrapResponse(response != null ? response: connect.response, connect.isIncluded));

  @override
  HttpConnect get forwarder => origin;
  @override
  bool get isForwarded => true;
}

///HttpConnect for included request
class _IncludedConnect extends _ProxyConnect {
  ///[uri]: if null, it means no need to change
  _IncludedConnect(HttpConnect connect, HttpRequest? request,
    HttpResponse? response, String? uri):
    super(connect,
      _wrapRequest(request != null ? request: connect.request, uri),
      _wrapResponse(response != null ? response: connect.response, true));

  @override
  HttpConnect get includer => origin;
  @override
  bool get isIncluded => true;
}

///Request for renaming URI.
class _ReUriRequest extends HttpRequestWrapper {
  _ReUriRequest(HttpRequest request, this._uri): super(request);

  final Uri _uri;

  @override
  Uri get uri => _uri;
}

///Ignore any invocation alerting the headers
class _IncludedResponse extends HttpResponseWrapper {
  _IncludedResponse(HttpResponse response): super(response);

  HttpHeaders? _headers;

  //Note: we don't override set:statusCode since we have to report the error
  //back to the browser if it happens in the included renderer

  @override
  void set contentLength(int contentLength) {
  }

  @override
  HttpHeaders get headers
  => _headers ??= _ReadOnlyHeaders(origin.headers);

  @override
  Future<Socket> detachSocket({bool writeHeaders = true}) {
    throw HttpException("Not allowed in an included connection");
  }
}
///Immutable HTTP headers. It ignores any writes.
class _ReadOnlyHeaders extends HttpHeadersWrapper {
  _ReadOnlyHeaders(HttpHeaders headers): super(headers);

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
  }

  @override
  void remove(String name, Object value) {
  }
  @override
  void removeAll(String name) {
  }
  @override
  void set date(DateTime? date) {
  }
  @override
  void noFolding(String name) {
  }
  @override
  void set expires(DateTime? expires) {
  }
  @override
  void set ifModifiedSince(DateTime? ifModifiedSince) {
  }
  @override
  void set host(String? host) {
  }
  @override
  void set port(int? port) {
  }
  @override
  void clear() {
  }
  @override
  void set chunkedTransferEncoding(bool value) {
  }
  @override
  void set contentType(ContentType? contentType) {
  }
  @override
  void set contentLength(int contentLength) {
  }
  @override
  void set persistentConnection(bool value) {
  }
}

///[uri]: if null, it means no need to change
///[keepQuery]: whether to keep the original query parameters
HttpRequest _wrapRequest(HttpRequest request, String? path, {bool keepQuery =false}) {
  if (path == null)
    return request;

  final org = request.uri;
  String query;
  if (keepQuery) {
    query = org.query;
  } else {
    query = "";

    final i = path.indexOf('?');
    if (i >= 0) {
      query = path.substring(i + 1);
      path = path.substring(0, i);
    }
	}

  path = _toAbsUri(request, path);

  if (org.path == path && org.query == query)
    return request;

  return _ReUriRequest(request, Uri(scheme: org.scheme,
    userInfo: org.userInfo, port: org.port, path: path, query: query,
    fragment: org.fragment));
}
HttpResponse _wrapResponse(HttpResponse response, bool included)
=> !included || response is _IncludedResponse ?
      response: _IncludedResponse(response);

String _toAbsUri(HttpRequest request, String uri) {
  if (!uri.startsWith('/')) {
    final pre = request.uri.path;
    final i = pre.lastIndexOf('/');
    if (i >= 0)
      uri = "${pre.substring(0, i + 1)}$uri";
    else
      uri = "/$uri";
  }
  return uri;
}
String _toCompleteUrl(HttpRequest request, String uri)
=> _completeUriRegex.hasMatch(uri) ? uri:
  request.uri.resolve(_toAbsUri(request, uri)).toString();
final _completeUriRegex = RegExp(r"^[a-zA-Z]+://");

class _Browser extends Browser {
  _Browser(this.userAgent);

  @override
  final String userAgent;
}
