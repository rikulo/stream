//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Jan 08, 2013 12:04:43 PM
// Author: tomyeh
part of stream;

/** A HTTP request connection.
 */
abstract class HttpConnect {
  ///The Stream server
  StreamServer get server;
  ///The HTTP request.
  HttpRequest get request;
  ///The HTTP response.
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

  /** A safe invocation for `Future.then(onValue)`. It will invoke
   * `connect.error(err, stackTrace)` automatically if there is an exception.
   * It is strongly suggested to use this method instead of calling `Future.then`
   * directly when handling an request asynchronously. For example,
   *
   *     connect.then(file.exists, (exists) {
   *       if (exists)
   *           doSomething(); //any exception will be caught and handled
   *       throw new Http404();
   *     }
   */
  void then(Future future, onValue(value));

  /** The error handler.
   *
   * Notice that it is important to invoke this method if an error occurs.
   * Otherwise, the HTTP connection won't be closed.
   *
   * ##Use `HttpConnect.then` instead of `Future.then`
   *
   * When using with `Future.then`, you have to implement a catch-all statement
   * to invoke `connect.error(err, st)` when an error occurs.
   *
   * To simplify the job, you can invoke [then] (of `HttpConnect`) instead of
   * invoking `Future.then` directly.
   * [then] will invoke `connect.error(err, st)` automatically if necessary.
   * For example,
   *
   *     connect.then(file.exists, (exists) {
   *       if (exists)
   *           doSomething(); //any exception will be caught and handled
   *       throw new Http404();
   *     }
   *
   * ##Assign onError with this method
   *
   * For example,
   *
   *     file.openInputStream()
   *       ..onError = connect.error
   *       ..pipe(connect.response.outputStream, close: true);
   */
  ErrorHandler get error;
  /** Indicates if any error occurs (i.e., [error] has been called).
   */
  bool isError;
}

class _HttpConnex implements HttpConnect {
  final ConnexErrorHandler _cxerrh;
  ErrorHandler _errh;

  _HttpConnex(StreamServer this.server, HttpRequest this.request,
    HttpResponse this.response, ConnexErrorHandler this._cxerrh) {
    _init();
  }
  void _init() {
    _errh = (e, [st]) {
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
  ErrorHandler get error => _errh;
  @override
  bool isError;
}

///A HTTP request that overrides the uri
class _UriRequest extends HttpRequestWrapper {
  final String _uri;
  _UriRequest(HttpRequest request, String this._uri): super(request);

  @override
  String get uri => _uri;
}

class _ForwardedConnex extends _HttpConnex {
  final bool _inc;

  _ForwardedConnex(HttpConnect connect, HttpRequest request,
    HttpResponse response, String uri, ConnexErrorHandler errorHandler):
    super(connect.server,
      new _UriRequest(request != null ? request: connect.request, uri),
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
class _IncludedConnex extends _HttpConnex {
  final bool _fwd;

  _IncludedConnex(HttpConnect connect, HttpRequest request,
    HttpResponse response, String uri, ConnexErrorHandler errorHandler):
    super(connect.server,
      new _UriRequest(request != null ? request: connect.request, uri),
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

/** A HTTP exception.
 */
class HttpException implements Exception {
  final int statusCode;
  String _msg;

  HttpException(int this.statusCode, [String message]) {
    if (message == null) {
      message = statusMessages[statusCode];
      if (message == null)
        message = "Unknown error";
    }
    _msg = message;
  }

  /** The error message. */
  String get message => _msg;

  String toString() => "HttpException($statusCode: $message)";
}
/// HTTP 403 exception.
class Http403 extends HttpException {
  Http403([String uri]): super(403, _status2msg(403, uri));
}
/// HTTP 404 exception.
class Http404 extends HttpException {
  Http404([String uri]): super(404, _status2msg(404, uri));
}
/// HTTP 500 exception.
class Http500 extends HttpException {
  Http500([String cause]): super(500, _status2msg(500, cause));
}
String _status2msg(int code, String cause)
=> cause != null ? "${statusMessages[code]}: $cause": null;

///A map of content types. For example, `contentTypes['js']` is `new ContentType.fromString("text/javascript;charset=utf-8")`.
Map<String, ContentType> contentTypes = {
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
    _stmsgs = new Map();
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
