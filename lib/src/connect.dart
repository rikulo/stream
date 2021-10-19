//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Jan 08, 2013 12:04:43 PM
// Author: tomyeh
part of stream;

/** A HTTP channel.
 * A channel represents the Internet address and port that [StreamServer]
 * is bound to.
 *
 * A channel can serve multiple HTTP connection ([HttpConnect]). A HTTP
 * connection is actually a pair of [HttpRequest] and [HttpResponse].
 */
abstract class HttpChannel {
  ///The connection information summarizing the number of current connections
  //handled in this channel.
  HttpConnectionsInfo get connectionsInfo;
  /** When the server started. It is null if never started.
   * 
   * > Note: we use [startedSince] to set LAST_MODIFIED if
   * > `lastModified="start"`.
   */
  DateTime get startedSince;

  /** Closes the channel.
   *
   * To start all channels, please use [StreamServer.stop] instead.
   */
  Future close();
  /** Indicates whether the channel is closed.
   */
  bool get isClosed;

  ///The Stream server for serving this channel.
  StreamServer get server;

  /** The internal HTTP server for serving this channel.
   * 
   * Note: [server] starts one or multiple [HttpServer] instances to serve
   * one or multiple channels. Each channel is served by one [HttpServer] instance.
   */
  HttpServer get httpServer;

  ///The socket that this channel is bound to.
  ///It is available only if the channel is started by [StreamServer.startOn].
  ServerSocket? get socket;

  /** The address. It can be either a [String] or an [InternetAddress].
   * It is null if the channel is started by [StreamServer.startOn].
   */
  get address;
  ///The port.
  int get port;
  ///Whether it is a HTTPS channel
  bool get isSecure;
}

/** The request filter. It is used with the `filterMapping` parameter of [StreamServer].
 *
 * * [chain] - the callback to *resume* the request handling. If there is another filter
 * (including the default handling, such as URI mapping and resource loading),
 * it will be invoked when you call back [chain].
 * If you'd like to skip the handling (e.g., redirect to another page),
 * you don't have to call back [chain].
 *
 * Before calling back [chain], you can proxy the request and/or response, such as writing the
 * the response to a string buffer.
 */
typedef Future RequestFilter(HttpConnect connect, Future chain(HttpConnect conn));
/** The request handler.
 *
 * If a request handler finishes immediately, it doesn't have to return anything.
 * For example,
 *
 *     void serverInfo(HttpConnect connect) {
 *       final info = {"name": "Rikulo Stream", "version": connect.server.version};
 *       connect.response
 *         ..headers.contentType = getContentType("json")
 *         ..write(jsonEncode(info));
 *     }
 *
 * On the other hand, if a request is handled asynchronously, it *must* return
 * an instance of [Future] for indicating if the handling is completed. For example,
 *
 *     Future loadFile(HttpConnect connect) {
 *       final completer = new Completer();
 *       final res = connect.response;
 *       new File("some_file").openRead().listen(res.writeBytes);},
 *         onDone: () => completer.complete(),
 *         onError: (err, stackTrace) => completer.completeError(err, stackTrace));
 *       return completer.future;
 *     }
 *
 * As shown above, the error has to be *wired* to the Future object being returned.
 *
 * > The returned `Future` object can carry any type of objects. It is applications
 * specific. Stream server simply ignores it.
 *
 * > Though not specified, the handler can have any number of named arguments.
 * They are application specific. Stream server won't pass anything but the default
 * values.
 */
typedef Future RequestHandler(HttpConnect connect);

/** A HTTP request connection.
 */
abstract class HttpConnect {
  /** Instantiates a connection by redirecting the output to the given buffer
   * (bytes).
   */
  factory HttpConnect.buffer(HttpConnect origin, List<int> buffer)
  => new _BufferedConnect(origin, buffer);
  /** Instantiates a connection by redirecting the output to the given
   * string buffer.
   */
  factory HttpConnect.stringBuffer(HttpConnect origin, StringBuffer buffer)
  => new _StringBufferedConnect(origin, buffer);
  /** Instantiates a connection that will be used to include or forward to
   * another request handler.
   *
   * * [uri] - the URI to chain with. If omitted, it is the same as [connect]'s.
   * It can contain the query string too.
   * * [inclusion] - whether it is used for inclusion. If true,
   * any modification to `connect.response.headers` is ignored.
   */
  factory HttpConnect.chain(HttpConnect connect, {bool inclusion: true,
      String? uri, HttpRequest? request, HttpResponse? response}) {
    return inclusion ?
      new _IncludedConnect(connect, request, response, uri):
      new _ForwardedConnect(connect, request, response, uri);
  }

  ///The Stream server
  StreamServer get server;
  ///The channel that this connection is on.
  HttpChannel get channel;
  ///The HTTP request.
  HttpRequest get request;
  /** The HTTP response.
   *
   * Notice that you shall *NOT* invoke `response.close()`, since it was
   * called automatically when the serving of a request is finished.
   */
  HttpResponse get response;
  ///The source connection that forwards to this connection, or null if not forwarded.
  HttpConnect? get forwarder;
  ///The source connection that includes this connection, or null if not included.
  HttpConnect? get includer;
  /** Whether this connection is caused by inclusion.
   * Note: it is true if [includer] is not null or [forwarder] is included.
   */
  bool get isIncluded;
  /** Whether this connection is caused by forwarding.
   * Note: it is true if [forwarder] is not null or [includer] is forwarded.
   */
  bool get isForwarded;

  /** Send a temporary redirect to the specified redirect URL.
   *
   * * [url] - the location to redirect to. It can be an URI or URL, such as
   * `/login?whatever` and `http://rikulo.org/project/stream`.
   *
   * > Notice: you shall invoke this method instead of `HttpResponse.redirect()`,
   * since `HttpResponse.redirect()` will close the connection (which
   * will be called automatically under Rikulo Stream).
   */
  void redirect(String url, {int status: HttpStatus.movedTemporarily});

  /** Forward this connection to the given [uri].
   *
   * If [request] and/or [response] is ignored, the request and/or response
   * of this connection is assumed.
   * If [uri] is null, `connect.uri` is assumed, i.e., forwarded to the same handler.
   *
   * After calling this method, the caller shall write the output stream in `then`, since
   * the request handler for the given URI might handle it asynchronously. For example,
   *
   *     await connect.forward(connect, "another");
   *     connect.response.write("<p>More content</p>");
   *     ...
   *
   * * [uri] - the URI to chain. If omitted, it is the same as this connection.
   * It can contain the query string too.
   *
   * ##Difference between [forward] and [include]
   *
   * [forward] and [include] are almost the same, except
   *
   * * The included request handler won't be able to generate any HTTP headers
   * (it is the job of the caller). Any updates to HTTP headers in the included
   * request handler are simply ignored.
   *
   * Notice the default implementation is `connect.forward(connect, uri...)`.
   */
  Future forward(String uri, {HttpRequest? request, HttpResponse? response});
  /** Includes the given [uri].
   *
   * If [request] or [response] is ignored, this connect's request or response is assumed.
   * If [uri] is null, `connect.uri` is assumed, i.e., includes the same handler.
   *
   * After calling this method, the caller shall write the output stream in `then`, since
   * the request handler for the given URI might handle it asynchronously. For example,
   *
   *     await connect.include(connect, "another");
   *     connect.response.write("<p>More content</p>");
   *     ...
   *
   * * [uri] - the URI to chain. If omitted, it is the same as this connection.
   * It can contain the query string too.
   *
   * ##Difference between [forward] and [include]
   *
   * [forward] and [include] are almost the same, except
   *
   * * The included request handler won't be able to generate any HTTP headers
   * (it is the job of the caller). Any updates to HTTP headers in the included
   * request handler are simply ignored.
   *
   * Notice the default implementation is `connect.include(connect, uri...)`.
   */
  Future include(String uri, {HttpRequest? request, HttpResponse? response});

  /** The browser information.
   *
   * * See also [Browser](http://api.rikulo.org/commons/latest/rikulo_browser/Browser.html).
   */
  Browser get browser;

  /** Returns the first value of the given [name] of [request]'s headers.
   * Unlike [HttpHeaders.value], this method won't throw any exception.
   * Rather, it simply picks the first header if any.
   */
  String? headerValue(String name);

  /** The preferred Locale that the client will accept content in,
   * based on the Accept-Language header.
   */
  String get locale;
  /** A readonly list of Locales indicating, in decreasing order starting with
  * the preferred locale, the locales that are acceptable to the client based
  * on the Accept-Language header
  */
  List<String> get locales;

  /** The error detailed information, or null if no error occurs.
   */
  ErrorDetail? errorDetail;

  /** A map of application-specific data.
   *
   * Note: the name of the keys can't start with "stream.", which is reserved
   * for internal use.
   */
  Map<String, dynamic> get dataset;

  /// Returns whether to close [response] after serving a request.
  /// Default: true.
  bool autoClose = true;
}

///The HTTP connection wrapper. It simplifies the overriding of a connection.
class HttpConnectWrapper implements HttpConnect {
  ///The original HTTP request
  final HttpConnect origin;
 
  HttpConnectWrapper(this.origin);

  @override
  StreamServer get server => origin.server;
  @override
  HttpChannel get channel => origin.channel;
  @override
  HttpRequest get request => origin.request;
  @override
  HttpResponse get response => origin.response;
  @override
  HttpConnect? get forwarder => origin.forwarder;
  @override
  HttpConnect? get includer => origin.includer;
  @override
  bool get isIncluded => origin.isIncluded;
  @override
  bool get isForwarded => origin.isForwarded;

  @override
  void redirect(String uri, {int status: HttpStatus.movedTemporarily}) {
    origin.redirect(_toCompleteUrl(request, uri), status: status);
  }
  @override
  Future forward(String uri, {HttpRequest? request, HttpResponse? response})
  => origin.forward(uri, request: request ?? this.request,
    response: response != null ? response: this.response);
  @override
  Future include(String uri, {HttpRequest? request, HttpResponse? response})
  => origin.include(uri, request: request ?? this.request,
    response: response != null ? response: this.response);

  @override
  Browser get browser => origin.browser;
  @override
  String? headerValue(String name) => origin.headerValue(name);

  @override
  String get locale => origin.locale;
  @override
  List<String> get locales => origin.locales;
  @override
  ErrorDetail? get errorDetail => origin.errorDetail;
  @override
  void set errorDetail(ErrorDetail? errorDetail) {
    origin.errorDetail = errorDetail;
  }

  @override
  Map<String, dynamic> get dataset => origin.dataset;

  @override
  bool get autoClose => origin.autoClose;
  @override
  void set autoClose(bool auto) {
    origin.autoClose = auto;
  }
}

///The error detailed information.
class ErrorDetail {
  var error;
  var stackTrace;
  ErrorDetail(this.error, this.stackTrace);
}

/** A HTTP status exception.
 */
class HttpStatusException extends HttpException {
  final int statusCode;

  HttpStatusException(int this.statusCode, {Uri? uri, String? message})
  : super(message ?? statusCode.toString(), uri: uri);
  HttpStatusException.fromConnect(HttpConnect connect, int statusCode,
    {String? message})
  : this(statusCode, uri: connect.request.uri, message: message);

  @override
  String toString() {
    final statusText = statusCode.toString(),
      b = new StringBuffer()..write(statusText)..write(': ');
    if (statusText != message) {
      b.write(message);
      if (uri != null) b.write(', ');
    }
    if (uri != null) b..write('uri=')..write(uri);
    return b.toString();
  }
}

/// HTTP 400 exception.
class Http400 extends HttpStatusException {
  Http400({Uri? uri, String? message}): super(400, uri: uri, message: message);
  Http400.fromConnect(HttpConnect connect, {String? message})
  : super.fromConnect(connect, 400, message: message);
}
/// HTTP 401 exception.
class Http401 extends HttpStatusException {
  Http401({Uri? uri, String? message}): super(401, uri: uri, message: message);
  Http401.fromConnect(HttpConnect connect, {String? message})
  : super.fromConnect(connect, 401, message: message);
}
/// HTTP 402 exception.
class Http402 extends HttpStatusException {
  Http402({Uri? uri, String? message}): super(402, uri: uri, message: message);
  Http402.fromConnect(HttpConnect connect, {String? message})
  : super.fromConnect(connect, 402, message: message);
}
/// HTTP 403 exception.
class Http403 extends HttpStatusException {
  Http403({Uri? uri, String? message}): super(403, uri: uri, message: message);
  Http403.fromConnect(HttpConnect connect, {String? message})
  : super.fromConnect(connect, 403, message: message);
}
/// HTTP 404 exception.
class Http404 extends HttpStatusException {
  Http404({Uri? uri, String? message}): super(404, uri: uri, message: message);
  Http404.fromConnect(HttpConnect connect, {String? message})
  : super.fromConnect(connect, 404, message: message);
}
/// HTTP 405 exception.
class Http405 extends HttpStatusException {
  Http405({Uri? uri, String? message}): super(405, uri: uri, message: message);
  Http405.fromConnect(HttpConnect connect, {String? message})
  : super.fromConnect(connect, 405, message: message);
}
/// HTTP 406 exception.
class Http406 extends HttpStatusException {
  Http406({Uri? uri, String? message}): super(406, uri: uri, message: message);
  Http406.fromConnect(HttpConnect connect, {String? message})
  : super.fromConnect(connect, 406, message: message);
}
/// HTTP 408 exception.
class Http408 extends HttpStatusException {
  Http408({Uri? uri, String? message}): super(408, uri: uri, message: message);
  Http408.fromConnect(HttpConnect connect, {String? message})
  : super.fromConnect(connect, 408, message: message);
}
/// HTTP 409 exception.
class Http409 extends HttpStatusException {
  Http409({Uri? uri, String? message}): super(409, uri: uri, message: message);
  Http409.fromConnect(HttpConnect connect, {String? message})
  : super.fromConnect(connect, 409, message: message);
}
/// HTTP 410 exception.
class Http410 extends HttpStatusException {
  Http410({Uri? uri, String? message}): super(410, uri: uri, message: message);
  Http410.fromConnect(HttpConnect connect, {String? message})
  : super.fromConnect(connect, 410, message: message);
}
/// HTTP 412 exception.
class Http412 extends HttpStatusException {
  Http412({Uri? uri, String? message}): super(412, uri: uri, message: message);
  Http412.fromConnect(HttpConnect connect, {String? message})
  : super.fromConnect(connect, 412, message: message);
}
/// HTTP 413 exception.
class Http413 extends HttpStatusException {
  Http413({Uri? uri, String? message}): super(413, uri: uri, message: message);
  Http413.fromConnect(HttpConnect connect, {String? message})
  : super.fromConnect(connect, 413, message: message);
}
/// HTTP 418 exception.
class Http418 extends HttpStatusException {
  Http418({Uri? uri, String? message}): super(418, uri: uri, message: message);
  Http418.fromConnect(HttpConnect connect, {String? message})
  : super.fromConnect(connect, 418, message: message);
}
/// HTTP 429 exception.
class Http429 extends HttpStatusException {
  Http429({Uri? uri, String? message}): super(429, uri: uri, message: message);
  Http429.fromConnect(HttpConnect connect, {String? message})
  : super.fromConnect(connect, 429, message: message);
}

/// HTTP 500 exception.
class Http500 extends HttpStatusException {
  Http500({Uri? uri, String? cause})
  : super(500, uri: uri, message: cause != null ? "500: $cause": null);
  Http500.fromConnect(HttpConnect connect, {String? cause})
  : super.fromConnect(connect, 500, message: cause != null ? "500: $cause": null);
}
/// HTTP 501 exception.
class Http501 extends HttpStatusException {
  Http501({Uri? uri, String? cause})
  : super(501, uri: uri, message: cause != null ? "501: $cause": null);
  Http501.fromConnect(HttpConnect connect, {String? cause})
  : super.fromConnect(connect, 501, message: cause != null ? "501: $cause": null);
}
/// HTTP 503 exception.
class Http503 extends HttpStatusException {
  Http503({Uri? uri, String? cause})
  : super(503, uri: uri, message: cause != null ? "503: $cause": null);
  Http503.fromConnect(HttpConnect connect, {String? cause})
  : super.fromConnect(connect, 503, message: cause != null ? "503: $cause": null);
}
