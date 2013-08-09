//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Fri, Jan 18, 2013  9:26:05 AM
// Author: tomyeh
part of stream;

///Skeletal implementation
abstract class _AbstractConnect implements HttpConnect {
  Map<String, dynamic> _dataset;
 
  _AbstractConnect(this.request, this.response);

  @override
  final HttpRequest request;
  @override
  final HttpResponse response;
  @override
  HttpConnect get forwarder => null;
  @override
  HttpConnect get includer => null;
  @override
  bool get isIncluded => false;
  @override
  bool get isForwarded => false;

  @override
  void redirect(String uri, {int status: HttpStatus.MOVED_TEMPORARILY}) {
    response.statusCode = status;
    response.headers.set("Location", _toCompleteUrl(request, uri));
  }
  @override
  Future forward(String uri, {HttpRequest request, HttpResponse response})
  => server.forward(this, uri, request: request, response: response);
  @override
  Future include(String uri, {HttpRequest request, HttpResponse response})
  => server.include(this, uri, request: request, response: response);
}

///The default implementation of HttpConnect
class _HttpConnect extends _AbstractConnect {
  Browser _browser;

  _HttpConnect(this.channel, HttpRequest request, HttpResponse response):
      super(request, response);

  @override
  StreamServer get server => channel.server;
  @override
  final HttpChannel channel;

  @override
  Browser get browser {
    if (_browser == null) {
      final ua = request.headers.value("User-Agent");
      _browser = new _Browser(ua != null ? ua: "");
    }
    return _browser;
  }

  @override
  ErrorDetail errorDetail;
  @override
  Map<String, dynamic> get dataset
  => _dataset != null ? _dataset: MapUtil.onDemand(() => _dataset = new HashMap());
}

class _ProxyConnect extends _AbstractConnect {
  final HttpConnect _origin;

  _ProxyConnect(HttpConnect origin, HttpRequest request, HttpResponse response):
      _origin = origin, super(request, response);

  @override
  StreamServer get server => _origin.server;
  @override
  HttpChannel get channel => _origin.channel;
  @override
  Browser get browser => _origin.browser;
  @override
  ErrorDetail get errorDetail => _origin.errorDetail;
  @override
  void set errorDetail(ErrorDetail errorDetail) {
    _origin.errorDetail = errorDetail;
  }
  @override
  bool get isIncluded => _origin.isIncluded;
  @override
  bool get isForwarded => _origin.isForwarded;
  @override
  Map<String, dynamic> get dataset => _origin.dataset;
}

class _BufferedConnect extends _ProxyConnect {
  _BufferedConnect(HttpConnect connect, List<int> buffer):
    super(connect, connect.request,
        new BufferedResponse(connect.response, buffer));
}
class _StringBufferedConnect extends _ProxyConnect {
  _StringBufferedConnect(HttpConnect connect, StringBuffer buffer):
    super(connect, connect.request,
        new StringBufferedResponse(connect.response, buffer));
}

///HttpConnect for forwarded request
class _ForwardedConnect extends _ProxyConnect {
  ///[uri]: if null, it means no need to change
  _ForwardedConnect(HttpConnect connect, HttpRequest request,
    HttpResponse response, String uri):
    super(connect,
      _wrapRequest(request != null ? request: connect.request, uri),
      _wrapResponse(response != null ? response: connect.response, connect.isIncluded));

  @override
  HttpConnect get forwarder => _origin;
  @override
  bool get isForwarded => true;
}

///HttpConnect for included request
class _IncludedConnect extends _ProxyConnect {
  ///[uri]: if null, it means no need to change
  _IncludedConnect(HttpConnect connect, HttpRequest request,
    HttpResponse response, String uri):
    super(connect,
      _wrapRequest(request != null ? request: connect.request, uri),
      _wrapResponse(response != null ? response: connect.response, true));

  @override
  HttpConnect get includer => _origin;
  @override
  bool get isIncluded => true;
}

///Request for renaming URI.
class _ReUriRequest extends HttpRequestWrapper {
  _ReUriRequest(request, this._uri): super(request);

  final Uri _uri;

  @override
  Uri get uri => _uri;
}

///Ignore any invocation alerting the headers
class _IncludedResponse extends HttpResponseWrapper {
  _IncludedResponse(HttpResponse response): super(response);

  HttpHeaders _headers;

  //Note: we don't override set:statusCode since we have to report the error
  //back to the browser if it happens in the included renderer

  @override
  void set contentLength(int contentLength) {
  }

  @override
  HttpHeaders get headers {
    if (_headers == null)
      _headers = new _ReadOnlyHeaders(origin.headers);
    return _headers;
  }

  @override
  Future<Socket> detachSocket() {
    throw new HttpException("Not allowed in an included connection");
  }
}
///Immutable HTTP headers. It ignores any writes.
class _ReadOnlyHeaders extends HttpHeadersWrapper {
  _ReadOnlyHeaders(HttpHeaders headers): super(headers);

  @override
  void add(String name, Object value) {
  }
  @override
  void set(String name, Object value) {
  }
  @override
  void remove(String name, Object value) {
  }
  @override
  void removeAll(String name) {
  }
  @override
  void set date(DateTime date) {
  }
  @override
  void set expires(DateTime expires) {
    origin.expires = expires;
  }
  @override
  void set ifModifiedSince(DateTime ifModifiedSince) {
  }
  @override
  void set host(String host) {
  }
  @override
  void set port(int port) {
  }
  @override
  void set contentType(ContentType contentType) {
  }
  @override
  void set chunkedTransferEncoding(bool chunkedTransferEncoding) {
  }
}

///[uri]: if null, it means no need to change
///[keepQuery]: whether to keep the original query parameters
HttpRequest _wrapRequest(HttpRequest request, String path, {bool keepQuery:false}) {
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

  return new _ReUriRequest(request, new Uri(scheme: org.scheme,
    userInfo: org.userInfo, port: org.port, path: path, query: query,
    fragment: org.fragment));
}
HttpResponse _wrapResponse(HttpResponse response, bool included)
=> !included || response is _IncludedResponse ? response: new _IncludedResponse(response);

String _toAbsUri(HttpRequest request, String uri) {
  if (uri != null && !uri.startsWith('/')) {
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
final RegExp _completeUriRegex = new RegExp(r"^[a-zA-Z]+://");

class _Browser extends Browser {
  _Browser(this.userAgent);

  @override
  final String userAgent;
}