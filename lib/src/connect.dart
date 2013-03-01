//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Jan 08, 2013 12:04:43 PM
// Author: tomyeh
part of stream;

/** The general handler. */
typedef void Handler();
/** The error handler. */
typedef void ErrorHandler(err, [stackTrace]);
/** The error handler for HTTP connection. */
typedef void ConnectErrorHandler(HttpConnect connect, err, [stackTrace]);

/** A HTTP request connection.
 */
abstract class HttpConnect {
  ///The Stream server
  StreamServer get server;
  ///The HTTP request.
  HttpRequest get request;
  /** The HTTP response.
   *
   * Notice that it is suggested to invoke [close] instead of `response.close()` when finishing
   * a serving, because the request handler might be included or forwarded by another, which
   * might have further task to do (and will register the task by use `on.close.add()`).
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

  /** Forward this connection to the given [uri].
   *
   * If [request] or [response] is ignored, this connect's request or response is assumed.
   *
   * After calling this method, the caller shall not write the output stream, since the
   * request handler for the given URI might handle it asynchronously. Rather, it
   * shall make it a closure and pass it to the [success] argument. Then,
   * it will be resumed once the forwarded handler has completed.
   *
   * ##Difference between [forward] and [include]
   *
   * [forward] and [include] are almost the same, except
   *
   * * The included request handler shall not generate any HTTP headers (it is the job of the caller).
   *
   * * The request handler that invokes [forward] shall not call [close] (it is the job
   * of the callee -- the forwarded request handler).
   *
   * Notice the default implementation is `connect.forward(connect, uri...)`.
   */
  void forward(String uri, {Handler success, HttpRequest request, HttpResponse response});
  /** Includes the given [uri].
   * If you'd like to include a request handler (i.e., a function), use [StreamServer]'s
   * `connectForInclusion` instead.
   *
   * If [request] or [response] is ignored, this connect's request or response is assumed.
   *
   * After calling this method, the caller shall not write the output stream, since the
   * request handler for the given URI might handle it asynchronously. Rather, it
   * shall make it a closure and pass it to the [success] argument. Then,
   * it will be resumed once the included handler has completed.
   *
   * ##Difference between [forward] and [include]
   *
   * [forward] and [include] are almost the same, except
   *
   * * The included request handler shall not generate any HTTP headers (it is the job of the caller).
   *
   * * The request handler that invokes [forward] shall not call [close] (it is the job
   * of the callee -- the included request handler).
   *
   * Notice the default implementation is `connect.include(connect, uri...)`.
   */
  void include(String uri, {Handler success, HttpRequest request, HttpResponse response});

  /** The map of error and close handlers.
   * It is used to register the handler that will be called when an error occurs, or when [close]
   * is called, depending which list it is registered.
   *
   * Notice the sequence of invocation is reversed, i.e., the first added is the last called.
   */
  HandlerMap get on;
  /** The close handler.
   * After finishing the handling of a request, the request handler shall invoke this method
   * to start the awaiting task, or to
   * close the connection (depending on if the request handler is included / forwarded).
   *
   * To register an awaiting task that shall be run after the request handling, you can invoke
   * `on.close.add()` (refer to [on]). To register an error handler, you can invoke `on.error.add()`.
   */
  Handler get close;
  /** The error handler.
   *
   * Notice that it is important to invoke this method if an error occurs.
   * Otherwise, the HTTP connection won't be closed, and, even worse, the server might stop from
   * execution.
   *
   * ##Assign onError with the return value of this method
   *
   *     file.openInputStream()
   *       ..onError = connect.error //forward to Stream's error handling
   *       ..onClosed = connect.close //close on completion
   *       ..pipe(connect.response.outputStream, close: true);
   *
   * ##Future.catchError with the return value of this method
   *
   *     file.exists().then((exists) {
   *       if (exists) {
   *         doSomething(); //any exception will be caught and handled
   *         connect.close(); //close on completion
   *         return;
   *       }
   *       throw new Http404();
   *     }).catchError(connect.error); //forward to Stream's error handling
   */
  ErrorHandler get error;
  /** The error detailed information (which is the information when [error]
   * has been called), or null if no error.
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
  void forward(String uri, {Handler success, HttpRequest request, HttpResponse response}) {
    origin.forward(uri, success: success, request: request, response: response);
  }
  @override
  void include(String uri, {Handler success, HttpRequest request, HttpResponse response}) {
    origin.include(uri, success: success, request: request, response: response);
  }

  @override
  HandlerMap get on => origin.on;
  @override
  Handler get close => origin.close;
  @override
  ErrorHandler get error => origin.error;
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

/** A list of handlers.
 * Notice the sequence of invocation is reversed, i.e., the first added is the last called.
 */
class HandlerList<T extends Function> {
  Queue<T> _handlers;

  /** Adds a handler.
   * Notice the sequence of invocation is reversed, i.e., the first added is the last called.
   */
  void add(T handler) {
    if (_handlers == null)
      _handlers = new Queue();
    _handlers.addFirst(handler);
  }
  void _invoke0() {
    if (_handlers != null)
      for (final h in _handlers)
        h();
  }
  void _invoke2(arg0, arg1) {
    if (_handlers != null)
      for (final h in _handlers)
        h(arg0, arg1);
  }
}
/** A map of handlers.
 */
class HandlerMap {
  HandlerList<Handler> _close;
  HandlerList<ErrorHandler> _error;

  /** The list of close handlers.
   * Notice the sequence of invocation is reversed, i.e., the first added is the last called.
   */
  final HandlerList<Handler> close = new HandlerList();
  /** The list of error handlers.
   * Notice the sequence of invocation is reversed, i.e., the first added is the last called.
   */
  final HandlerList<Handler> error = new HandlerList();
}

/** A HTTP status exception.
 */
class HttpStatusException implements HttpException {
  final int statusCode;
  String _msg;

  HttpStatusException(this.statusCode, [String message]) {
    if (message == null) {
      message = statusMessages[statusCode];
      if (message == null)
        message = "Unknown error";
    }
    _msg = message;
  }

  /** The error message. */
  String get message => _msg;

  String toString() => "HttpStatusException($statusCode: $message)";
}
/// HTTP 403 exception.
class Http403 extends HttpStatusException {
  Http403([String uri]): super(403, _status2msg(403, uri));
}
/// HTTP 404 exception.
class Http404 extends HttpStatusException {
  Http404([String uri]): super(404, _status2msg(404, uri));
}
/// HTTP 500 exception.
class Http500 extends HttpStatusException {
  Http500([String cause]): super(500, _status2msg(500, cause));
}
String _status2msg(int code, String cause)
=> cause != null ? "${statusMessages[code]}: $cause": null;

///A map of content types. For example, `contentTypes['js']` is `new ContentType.fromString("text/javascript;charset=utf-8")`.
final Map<String, ContentType> contentTypes = {
  'aac': new ContentType.fromString('audio/aac'),
  'aiff': new ContentType.fromString('audio/aiff'),
  'css': new ContentType.fromString('text/css;charset=utf-8'),
  'csv': new ContentType.fromString('text/csv;charset=utf-8'),
  'doc': new ContentType.fromString('application/vnd.ms-word'),
  'docx': new ContentType.fromString('application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
  'gif': new ContentType.fromString('image/gif'),
  'htm': new ContentType.fromString('text/html;charset=utf-8'),
  'html': new ContentType.fromString('text/html;charset=utf-8'),
  'ico': new ContentType.fromString('image/x-icon'),
  'jpg': new ContentType.fromString('image/jpeg'),
  'jpeg': new ContentType.fromString('image/jpeg'),
  'js': new ContentType.fromString('text/javascript;charset=utf-8'),
  'json': new ContentType.fromString('application/json;charset=utf-8'),
  'mid': new ContentType.fromString('audio/mid'),
  'mp3': new ContentType.fromString('audio/mp3'),
  'mp4': new ContentType.fromString('audio/mp4'),
  'mpg': new ContentType.fromString('video/mpeg'),
  'mpeg': new ContentType.fromString('video/mpeg'),
  'mpp': new ContentType.fromString('application/vnd.ms-project'),
  'odf': new ContentType.fromString('application/vnd.oasis.opendocument.formula'),
  'odg': new ContentType.fromString('application/vnd.oasis.opendocument.graphics'),
  'odp': new ContentType.fromString('application/vnd.oasis.opendocument.presentation'),
  'ods': new ContentType.fromString('application/vnd.oasis.opendocument.spreadsheet'),
  'odt': new ContentType.fromString('application/vnd.oasis.opendocument.text'),
  'pdf': new ContentType.fromString('application/pdf'),
  'png': new ContentType.fromString('image/png'),
  'ppt': new ContentType.fromString('application/vnd.ms-powerpoint'),
  'pptx': new ContentType.fromString('application/vnd.openxmlformats-officedocument.presentationml.presentation'),
  'rar': new ContentType.fromString('application/x-rar-compressed'),
  'rtf': new ContentType.fromString('application/rtf'),
  'txt': new ContentType.fromString('text/plain;charset=utf-8'),
  'wav': new ContentType.fromString('audio/wav'),
  'xls': new ContentType.fromString('application/vnd.ms-excel'),
  'xlsx': new ContentType.fromString('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  'xml': new ContentType.fromString('text/xml;charset=utf-8'),
  'zip': new ContentType.fromString('application/zip')
};

///A map of HTTP status code to messages.
Map<int, String> get statusMessages {
  if (_stmsgs == null) {
    _stmsgs = new HashMap();
    for (List<dynamic> inf in [
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
