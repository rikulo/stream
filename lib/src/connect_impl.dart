//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Fri, Jan 18, 2013  9:26:05 AM
// Author: tomyeh
part of stream;

///Skeletal implementation
abstract class _AbstractConnect implements HttpConnect {
  final ConnectErrorCallback _cxerrh;
  ErrorCallback _errh;
  Map<String, dynamic> _dataset;
 
  _AbstractConnect(this.request, this.response, this._cxerrh);

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
  Future forward(String uri, {HttpRequest request, HttpResponse response})
  => server.forward(this, uri, request: request, response: response);
  @override
  Future include(String uri, {HttpRequest request, HttpResponse response})
  => server.include(this, uri, request: request, response: response);

  @override
  ErrorCallback get error { //rarely used; defer it
    if (_errh == null)
      _errh = (e, [st]) {
        _cxerrh(this, e, st);
      };
    return _errh;
  }
}

///The default implementation of HttpConnect
class _HttpConnect extends _AbstractConnect {
  _HttpConnect(StreamServer server, HttpRequest request, HttpResponse response):
      this.server = server, super(request, response, server.defaultErrorCallback);

  @override
  final StreamServer server;
  @override
  ErrorDetail errorDetail;
  @override
  Map<String, dynamic> get dataset
  => _dataset != null ? _dataset: MapUtil.onDemand(() => _dataset = new HashMap());
}

class _ProxyConnect extends _AbstractConnect {
  final HttpConnect _origin;

  _ProxyConnect(HttpConnect origin, HttpRequest request, HttpResponse response):
      _origin = origin, super(request, response, origin.server.defaultErrorCallback);

  @override
  StreamServer get server => _origin.server;
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
  _BufferedConnect(HttpConnect connect, StringBuffer buffer):
    super(connect, connect.request, new BufferedResponse(connect.response, buffer));
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
  Map<String, String> _params;

  @override
  Uri get uri => _uri;
  @override
  Map<String, String> get queryParameters {
    if (_params == null)
      _params = HttpUtil.decodeQuery(uri.query);
    return _params;
  }
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
}

///[uri]: if null, it means no need to change
HttpRequest _wrapRequest(HttpRequest request, String uri) {
  if (uri == null)
    return request;

  final org = request.uri;
  final i = uri.indexOf('?');
  String query = "";
  if (i >= 0) {
    query = uri.substring(i + 1);
    uri = uri.substring(0, i);
  }
  uri = _toAbsUri(request, uri);
  if (org.path == uri && org.query == query)
    return request;

  return new _ReUriRequest(request, new Uri.fromComponents(scheme: org.scheme,
    userInfo: org.userInfo, port: org.port, path: uri, query: query,
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
