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
    }/*, onError: error*/); //TODO: wait for next SDK
  }

  @override
  final HandlerMap on = new HandlerMap();
  @override
  Handler get close => _close;
  @override
  ErrorHandler get error => _errh;
  @override
  bool isError;
}

///A HTTP request that overrides the uri
class _UriRequest extends HttpRequestWrapper {
  _UriRequest._(HttpRequest request, String this._uri): super(request);

  ///[uri]: if null, it means no need to change
  static HttpRequest get(HttpRequest request, String uri)
  => uri == null || request.uri == uri ? request: new _UriRequest._(request, uri);

  final String _uri;

  @override
  String get uri => _uri;
}

class _ForwardedConnect extends _HttpConnect {
  final bool _inc;

  ///[uri]: if null, it means no need to change
  _ForwardedConnect(HttpConnect connect, HttpRequest request,
    HttpResponse response, String uri, ConnectErrorHandler errorHandler):
    super(connect.server,
      _UriRequest.get(request != null ? request: connect.request, uri),
      response != null ? response: connect.response, errorHandler),
    forwarder = connect, _inc = connect.isIncluded;

  @override
  final HttpConnect forwarder;
  @override
  bool get isError => super.isError || forwarder.isError;
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
      _UriRequest.get(request != null ? request: connect.request, uri),
      response != null ? response: connect.response, errorHandler),
    includer = connect, _fwd = connect.isForwarded;

  @override
  final HttpConnect includer;
  @override
  bool get isError => super.isError || includer.isError;
  @override
  bool get isIncluded => true;
  @override
  bool get isForwarded => _fwd;
}

