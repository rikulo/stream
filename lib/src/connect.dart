//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Jan 08, 2013 12:04:43 PM
// Author: tomyeh
part of stream;

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
 *         ..headers.contentType = contentTypes["json"]
 *         ..write(Json.stringify(info));
 *     }
 *
 * On the other hand, if a request is handled asynchronously, it *must* return
 * an instance of [Future] for indicating if the handling is completed. For example,
 *
 *     Future loadFile(HttpConnect connect) {
 *       final completer = new Completer();
 *       final res = connect.response;
 *       new File("some_file").openRead().listen((data) {res.writeBytes(data);},
 *         onDone: () => completer.complete(),
 *         onError: (err) => completer.completeError(err));
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
      String uri, HttpRequest request, HttpResponse response}) {
    return inclusion ?
      new _IncludedConnect(connect, request, response, uri):
      new _ForwardedConnect(connect, request, response, uri);
  }

  ///The Stream server
  StreamServer get server;
  ///The HTTP request.
  HttpRequest get request;
  /** The HTTP response.
   *
   * Notice that you shall *NOT* invoke `response.close()`, since it was
   * called automatically when the serving of a request is finished.
   */
  HttpResponse get response;
  ///The source connection that forwards to this connection, or null if not forwarded.
  HttpConnect get forwarder;
  ///The source connection that includes this connection, or null if not included.
  HttpConnect get includer;
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
   */
  void redirect(String url);

  /** Forward this connection to the given [uri].
   *
   * If [request] and/or [response] is ignored, the request and/or response
   * of this connection is assumed.
   * If [uri] is null, `connect.uri` is assumed, i.e., forwarded to the same handler.
   *
   * After calling this method, the caller shall write the output stream in `then`, since
   * the request handler for the given URI might handle it asynchronously. For example,
   *
   *     connect.forward(connect, "another").then((_) {
   *       connect.response.write("<p>More content</p>");
   *       //...
   *     });
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
  Future forward(String uri, {HttpRequest request, HttpResponse response});
  /** Includes the given [uri].
   *
   * If [request] or [response] is ignored, this connect's request or response is assumed.
   * If [uri] is null, `connect.uri` is assumed, i.e., includes the same handler.
   *
   * After calling this method, the caller shall write the output stream in `then`, since
   * the request handler for the given URI might handle it asynchronously. For example,
   *
   *     connect.include(connect, "another").then((_) {
   *       connect.response.write("<p>More content</p>");
   *       //...
   *     });
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
  Future include(String uri, {HttpRequest request, HttpResponse response});

  /** Returns the browser information.
   *
   * * See also [Browser](http://api.rikulo.org/commons/latest/rikulo_browser/Browser.html).
   */
  Browser get browser;
  /** The error detailed information, or null if no error occurs.
   */
  ErrorDetail errorDetail;

  /** A map of application-specific data.
   *
   * Note: the name of the keys can't start with "stream.", which is reserved
   * for internal use.
   */
  Map<String, dynamic> get dataset;
}

///The HTTP connection wrapper. It simplifies the overriding of a connection.
class HttpConnectWrapper implements HttpConnect {
  ///The original HTTP request
  final HttpConnect origin;
 
  HttpConnectWrapper(this.origin);

  @override
  StreamServer get server => origin.server;
  @override
  HttpRequest get request => origin.request;
  @override
  HttpResponse get response => origin.response;
  @override
  HttpConnect get forwarder => origin.forwarder;
  @override
  HttpConnect get includer => origin.includer;
  @override
  bool get isIncluded => origin.isIncluded;
  @override
  bool get isForwarded => origin.isForwarded;

  @override
  void redirect(String uri) {
    origin.redirect(_toCompleteUrl(request, uri));
  }
  @override
  Future forward(String uri, {HttpRequest request, HttpResponse response})
  => origin.forward(uri, request: request != null ? request: this.request,
    response: response != null ? response: this.response);
  @override
  Future include(String uri, {HttpRequest request, HttpResponse response})
  => origin.include(uri, request: request != null ? request: this.request,
    response: response != null ? response: this.response);

  @override
  Browser get browser => origin.browser;
  @override
  ErrorDetail get errorDetail => origin.errorDetail;
  @override
  void set errorDetail(ErrorDetail errorDetail) {
    origin.errorDetail = errorDetail;
  }

  Map<String, dynamic> get dataset => origin.dataset;
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

  factory HttpStatusException(int statusCode, {String message, Uri uri}) {
    if (message == null) {
      message = statusMessages[statusCode];
      if (message == null)
        message = "Unknown error";
    }
    return new HttpStatusException._(statusCode, message, uri: uri);
  }
  HttpStatusException._(this.statusCode, String message, {Uri uri}):
    super(message, uri: uri);

  String toString() => "HttpStatusException($statusCode: $message)";
}
/// HTTP 403 exception.
class Http403 extends HttpStatusException {
  Http403([String path]): super._(403, _status2msg(403, path));
  Http403.uri(Uri uri): super._(403, _status2msg(403, uri.path), uri: uri);
  Http403.connect(HttpConnect connect): this.uri(connect.request.uri);
}
/// HTTP 404 exception.
class Http404 extends HttpStatusException {
  Http404([String path]): super._(404, _status2msg(404, path));
  Http404.uri(Uri uri): super._(404, _status2msg(404, uri.path), uri: uri);
  Http404.connect(HttpConnect connect): this.uri(connect.request.uri);
}
/// HTTP 500 exception.
class Http500 extends HttpStatusException {
  Http500([String cause]): super._(500, _status2msg(500, cause));
  Http500.uri(Uri uri, [String cause]): super._(500,
      _status2msg(500, cause != null ? "${uri.path}: $cause": uri.path), uri: uri);
  Http500.connect(HttpConnect connect, [String cause]):
      this.uri(connect.request.uri, cause);
}
String _status2msg(int code, String cause)
=> cause != null ? "${statusMessages[code]}: $cause": null;

///A map of content types. For example, `contentTypes['js']` is `ContentType.parse("text/javascript;charset=utf-8")`.
final Map<String, ContentType> contentTypes = {
  'aac': ContentType.parse('audio/aac'),
  'aiff': ContentType.parse('audio/aiff'),
  'css': ContentType.parse('text/css;charset=utf-8'),
  'csv': ContentType.parse('text/csv;charset=utf-8'),
  'cur': ContentType.parse('image/x-win-bitmap'),
  'dart': ContentType.parse('application/dart'),
  'doc': ContentType.parse('application/vnd.ms-word'),
  'docx': ContentType.parse('application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
  'eot': ContentType.parse('application/vnd.ms-fontobject'),
  'gif': ContentType.parse('image/gif'),
  'htm': ContentType.parse('text/html;charset=utf-8'),
  'html': ContentType.parse('text/html;charset=utf-8'),
  'ico': ContentType.parse('image/x-icon'),
  'jpg': ContentType.parse('image/jpeg'),
  'jpeg': ContentType.parse('image/jpeg'),
  'js': ContentType.parse('text/javascript;charset=utf-8'),
  'json': ContentType.parse('application/json;charset=utf-8'),
  'mid': ContentType.parse('audio/mid'),
  'mp3': ContentType.parse('audio/mp3'),
  'mp4': ContentType.parse('audio/mp4'),
  'mpg': ContentType.parse('video/mpeg'),
  'mpeg': ContentType.parse('video/mpeg'),
  'mpp': ContentType.parse('application/vnd.ms-project'),
  'odf': ContentType.parse('application/vnd.oasis.opendocument.formula'),
  'odg': ContentType.parse('application/vnd.oasis.opendocument.graphics'),
  'odp': ContentType.parse('application/vnd.oasis.opendocument.presentation'),
  'ods': ContentType.parse('application/vnd.oasis.opendocument.spreadsheet'),
  'odt': ContentType.parse('application/vnd.oasis.opendocument.text'),
  'otf': ContentType.parse('application/x-font-otf'),
  'pdf': ContentType.parse('application/pdf'),
  'png': ContentType.parse('image/png'),
  'ppt': ContentType.parse('application/vnd.ms-powerpoint'),
  'pptx': ContentType.parse('application/vnd.openxmlformats-officedocument.presentationml.presentation'),
  'rar': ContentType.parse('application/x-rar-compressed'),
  'rtf': ContentType.parse('application/rtf'),
  'svg': ContentType.parse('image/svg+xml'),
  'svgz': ContentType.parse('image/svg+xml'),
  'ttc': ContentType.parse('application/x-font-ttf'),
  'ttf': ContentType.parse('application/x-font-ttf'),
  'txt': ContentType.parse('text/plain;charset=utf-8'),
  'wav': ContentType.parse('audio/wav'),
  'woff': ContentType.parse('application/x-font-woff'),
  'xls': ContentType.parse('application/vnd.ms-excel'),
  'xlsx': ContentType.parse('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  'xml': ContentType.parse('text/xml;charset=utf-8'),
  'zip': ContentType.parse('application/zip')
};

///A map of HTTP status code to messages.
Map<int, String> get statusMessages {
  if (_stmsgs == null) {
    _stmsgs = new HashMap();
    for (List inf in [
  //http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
  [100, "Continue"],
  [101, "Switching Protocols"],
  [200, "OK"],
  [201, "Created"],
  [202, "Accepted"],
  [203, "Non-Authoritative Information"],
  [204, "No Content"],
  [205, "Reset Content"],
  [206, "Partial Content"],
  [300, "Multiple Choices"],
  [301, "Moved Permanently"],
  [302, "Found"],
  [303, "See Other"],
  [304, "Not Modified"],
  [305, "Use Proxy"],
  [307, "Temporary Redirect"],
  [400, "Bad Request"],
  [401, "Unauthorized"],
  [402, "Payment Required"],
  [403, "Forbidden"],
  [404, "Not found"],
  [405, "Method Not Allowed"],
  [406, "Not Acceptable"],
  [407, "Proxy Authentication Required"],
  [408, "Request Timeout"],
  [409, "Conflict"],
  [410, "Gone"],
  [411, "Length Required"],
  [412, "Precondition Failed"],
  [413, "Request Entity Too Large"],
  [414, "Request-URI Too Long"],
  [415, "Unsupported Media Type"],
  [416, "Requested Range Not Satisfiable"],
  [417, "Expectation Failed"],
  [500, "Internal Server Error"],
  [501, "Not Implemented"],
  [502, "Bad Gateway"],
  [503, "Service Unavailable"],
  [504, "Gateway Timeout"],
  [505, "HTTP Version Not Supported"]]) {
      _stmsgs[inf[0]] = inf[1];
    }
  }
  return _stmsgs;
}
Map<int, String> _stmsgs;
