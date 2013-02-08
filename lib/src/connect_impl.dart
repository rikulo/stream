//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Fri, Jan 18, 2013  9:26:05 AM
// Author: tomyeh
part of stream;

class _HttpConnect implements HttpConnect {
  final ConnectErrorHandler _cxerrh;
  ErrorHandler _errh;
  Handler _close;
 
  _HttpConnect(StreamServer this.server, HttpRequest this.request,
    HttpResponse this.response, ConnectErrorHandler this._cxerrh) {
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
  final StreamServer server;
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

  //@override
  void then(Future future, onValue(value)) {
    future.then((value) {
      try {
        onValue(value);
      } catch (e, st) {
        error(e, st);
      }
    }, onError: error);
  }

  @override
  final HandlerMap on = new HandlerMap();
  @override
  Handler get close => _close;
  @override
  ErrorHandler get error => _errh;
  @override
  ErrorDetail errorDetail;
}

///[uri]: if null, it means no need to change
HttpRequest _wrapRequest(HttpRequest request, String uri)
=> uri == null || request.uri == uri ? request: new _ReUriRequest(request, uri);
HttpResponse _wrapResponse(HttpResponse response, bool included)
=> !included || response is _IncludedResponse ? response: new _IncludedResponse(response);

class _ForwardedConnect extends _HttpConnect {
  final bool _inc;

  ///[uri]: if null, it means no need to change
  _ForwardedConnect(HttpConnect connect, HttpRequest request,
    HttpResponse response, String uri, ConnectErrorHandler errorHandler):
    super(connect.server,
      _wrapRequest(request != null ? request: connect.request, uri),
      _wrapResponse(response != null ? response: connect.response, connect.isIncluded),
      errorHandler),
    forwarder = connect, _inc = connect.isIncluded;

  @override
  final HttpConnect forwarder;
  @override
  ErrorDetail get errorDetail => forwarder.errorDetail;
  @override
  void set errorDetail(ErrorDetail errorDetail) {
    forwarder.errorDetail = errorDetail;
  }
  @override
  bool get isIncluded => _inc;
  @override
  bool get isForwarded => true;
}
class _IncludedConnect extends _HttpConnect {
  final bool _fwd;

  ///[uri]: if null, it means no need to change
  _IncludedConnect(HttpConnect connect, HttpRequest request,
    HttpResponse response, String uri, ConnectErrorHandler errorHandler):
    super(connect.server,
      _wrapRequest(request != null ? request: connect.request, uri),
      _wrapResponse(response != null ? response: connect.response, true),
      errorHandler),
    includer = connect, _fwd = connect.isForwarded;

  @override
  final HttpConnect includer;
  @override
  ErrorDetail get errorDetail => includer.errorDetail;
  @override
  void set errorDetail(ErrorDetail errorDetail) {
    includer.errorDetail = errorDetail;
  }
  @override
  bool get isIncluded => true;
  @override
  bool get isForwarded => _fwd;
}

class _ReUriRequest extends HttpRequestWrapper {
  _ReUriRequest(HttpRequest request, String this._uri): super(request);

  final String _uri;

  @override
  String get uri => _uri;
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
  DetachedSocket detachSocket() {
    throw new HttpException("Not allowed in an included connection");
  }
}
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
