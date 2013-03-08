//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Fri, Jan 18, 2013  9:26:05 AM
// Author: tomyeh
part of stream;

///Skeletal implementation
abstract class _AbstractConnect implements HttpConnect {
  final ConnectErrorHandler _cxerrh;
  ErrorHandler _errh;
  Handler _close;
  Map<String, dynamic> _dataset;
 
  _AbstractConnect(this.request, this.response, this._cxerrh) {
    _init();
  }
  void _init() {
    _close = () {
      on.close._invoke0();
    };
    _errh = (e, [st]) {
      on.error._invoke2(e, st);
      _cxerrh(this, e, st);
    };
  }

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
  void forward(String uri, {Handler success, HttpRequest request, HttpResponse response}) {
    server.forward(this, uri, success: success, request: request, response: response);
  }
  @override
  void include(String uri, {Handler success, HttpRequest request, HttpResponse response}) {
    server.include(this, uri, success: success, request: request, response: response);
  }

  @override
  final Handlers on = new Handlers();
  @override
  Handler get close => _close;
  @override
  ErrorHandler get error => _errh;
}

///The default implementation of HttpConnect
class _HttpConnect extends _AbstractConnect {
  _HttpConnect(this.server, HttpRequest request, HttpResponse response,
      ConnectErrorHandler cxerrh): super(request, response, cxerrh);

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

  ///[uri]: if null, it means no need to change
  _ProxyConnect(this._origin, HttpRequest request, HttpResponse response,
      ConnectErrorHandler errorHandler): super(request, response, errorHandler);

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
  _BufferedConnect(HttpConnect connect, StringBuffer buffer, [ConnectErrorHandler errorHandler]):
    super(connect, connect.request, new BufferedResponse(connect.response, buffer),
      errorHandler != null ? errorHandler: connect.error);
}

///HttpConnect for forwarded request
class _ForwardedConnect extends _ProxyConnect {
  ///[uri]: if null, it means no need to change
  _ForwardedConnect(HttpConnect connect, HttpRequest request,
    HttpResponse response, String uri, [ConnectErrorHandler errorHandler]):
    super(connect,
      _wrapRequest(request != null ? request: connect.request, uri),
      _wrapResponse(response != null ? response: connect.response, connect.isIncluded),
      errorHandler != null ? errorHandler: connect.error);

  @override
  HttpConnect get forwarder => _origin;
  @override
  bool get isForwarded => true;
}

///HttpConnect for included request
class _IncludedConnect extends _ProxyConnect {
  ///[uri]: if null, it means no need to change
  _IncludedConnect(HttpConnect connect, HttpRequest request,
    HttpResponse response, String uri, [ConnectErrorHandler errorHandler]):
    super(connect,
      _wrapRequest(request != null ? request: connect.request, uri),
      _wrapResponse(response != null ? response: connect.response, true),
      errorHandler != null ? errorHandler: connect.error);

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

  @override
  void set contentLength(int contentLength) {
  }
  @override
  void set statusCode(int statusCode) {
  }
  @override
  void set reasonPhrase(String reasonPhrase) {
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
HttpRequest _wrapRequest(HttpRequest request, String uri)
=> uri == null || request.uri == uri ? request: new _ReUriRequest(request, new Uri(uri));
HttpResponse _wrapResponse(HttpResponse response, bool included)
=> !included || response is _IncludedResponse ? response: new _IncludedResponse(response);
