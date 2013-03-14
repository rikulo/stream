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
  final _StreamTarget<HttpConnect> _closeEvtTarget = new _StreamTarget<HttpConnect>();
  _StreamTarget _errEvtTarget;
 
  _AbstractConnect(this.request, this.response, this._cxerrh) {
    _init();
  }
  void _init() {
    _close = () {
      _closeEvtTarget.send(this);
    };
    _errh = (e, [st]) {
      if (_errEvtTarget != null)
        _errEvtTarget.send(st != null ? new AsyncError(e, st): e);
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
  Handler get close => _close;
  @override
  ErrorHandler get error => _errh;
  @override
  Stream<HttpConnect> get onClose => _provider.forTarget(_closeEvtTarget);
  @override
  Stream get onError
  => _provider.forTarget(_errEvtTarget != null ? _errEvtTarget:
      (_errEvtTarget = new _StreamTarget()));
}

///The default implementation of HttpConnect
class _HttpConnect extends _AbstractConnect {
  _HttpConnect(StreamServer server, HttpRequest request, HttpResponse response):
      this.server = server, super(request, response, server.defaultErrorHandler);

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
  _ProxyConnect(HttpConnect origin, HttpRequest request, HttpResponse response):
      _origin = origin, super(request, response, origin.server.defaultErrorHandler);

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

//Close and error stream (for implementing HttpConnect.onClose and onError)
class _StreamTarget<T> implements StreamTarget<T> {
  Queue<Function> _listeners;

  _StreamTarget();

  void send(T event) {
    if (_listeners != null)
      for (final l in _listeners)
        l(event);
  }

  @override
  void addEventListener(String type, void listener(T event)) {
    if (_listeners == null)
      _listeners = new Queue();
    _listeners.addFirst(listener);
  }
  @override
  void removeEventListener(String type, void listener(T event)) {
    if (_listeners != null)
      _listeners.remove(listener);
  }
}
const StreamProvider _provider = const StreamProvider('');
