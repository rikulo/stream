//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Mar 12, 2013  7:08:29 PM
// Author: tomyeh
part of stream;

/** The error handler for HTTP connection. */
typedef void _ConnectErrorCallback(HttpConnect connect, err, [stackTrace]);

class _StreamServer implements StreamServer {
  final String version = "0.8.1";

  List<Channel> _channels = [];
  int _sessTimeout = 20 * 60; //20 minutes
  final Logger logger;
  String _homeDir;
  ResourceLoader _resLoader;
  final Router _router;
  _ConnectErrorCallback _onError;
  final bool _futureOnly;

  _StreamServer(this._router, String homeDir, LoggingConfigurer loggingConfigurer,
    this._futureOnly): logger = new Logger("stream") {
    (loggingConfigurer != null ? loggingConfigurer: new LoggingConfigurer())
      .configure(logger);
    _initDir(homeDir);
  }

  void _initDir(String homeDir) {
    _homeDir = homeDir == null ? _getRootPath():
      Path.isAbsolute(homeDir) ? homeDir: Path.join(_getRootPath(), homeDir);

    if (!new Directory(_homeDir).existsSync())
      throw new ServerError("$homeDir doesn't exist.");
    _resLoader = new ResourceLoader(_homeDir);
  }
  static String _getRootPath() {
    String path = new Options().script;
    path = path == null ? Path.current:
      Path.absolute(Path.normalize(Path.dirname(path)));

    //look for webapp
    for (final orgpath = path;;) {
      final String nm = Path.basename(path);
      final String op = path;
      path = Path.dirname(path);
      if (nm == "webapp")
        return path; //found and we use its parent as the root

      if (path == op //happens under Windows ("C:\")
          || path.isEmpty || path == Path.separator)
        return orgpath; //assume to be the same directory as script
    }
  }

  @override
  Future forward(HttpConnect connect, String uri, {
    HttpRequest request, HttpResponse response})
  => _handle(new HttpConnect.chain(connect, inclusion: false,
      uri: uri, request: request, response: response)); //no filter invocation
  @override
  Future include(HttpConnect connect, String uri, {
    HttpRequest request, HttpResponse response})
  => _handle(new HttpConnect.chain(connect, inclusion: true,
      uri: uri, request: request, response: response)); //no filter invocation

  ///[iFilter] - the index of filter to start. It must be non-negative. Ignored if null.
  Future _handle(HttpConnect connect, [int iFilter]) {
    try {
      String uri = connect.request.uri.path;
      if (!uri.startsWith('/'))
        uri = "/$uri"; //not possible; just in case

      if (iFilter != null) { //null means ignore filters
        iFilter = _router.getFilterIndex(connect, uri, iFilter);
        if (iFilter != null) //found
          return _ensureFuture(_router.getFilterAt(iFilter)(connect,
            (HttpConnect conn) => _handle(conn, iFilter + 1)));
      }

      var handler = _router.getHandler(connect, uri);
      if (handler != null) {
        if (handler is Function)
          return _ensureFuture(handler(connect));
        return forward(connect, handler); //must be a string
      }

      //protect from access
      if (!connect.isForwarded && !connect.isIncluded &&
      (uri.startsWith("/webapp/") || uri == "/webapp"))
        throw new Http403(uri);

      return resourceLoader.load(connect, uri);
    } catch (e, st) {
      return new Future.error(e, st);
    }
  }
  void _handleErr(HttpConnect connect, error, [stackTrace]) {
    if (stackTrace == null)
      stackTrace = getAttachedStackTrace(error);
    if (connect == null) {
      _shout(null, error, stackTrace);
      return;
    }

    try {
      if (_onError != null)
        _onError(connect, error, stackTrace);
      if (connect.errorDetail != null) { //called twice; ignore 2nd one
        _shout(connect, error, stackTrace);
        return; //done
      }

      bool shouted = false;
      connect.errorDetail = new ErrorDetail(error, stackTrace);
      var handler = _router.getErrorHandler(error);
      if (handler == null) {
        if (error is! HttpStatusException) {
          _shout(connect, error, stackTrace);
          shouted = true;
          error = new Http500(error);
        }

        final code = error.statusCode;
        connect.response.statusCode = code;
          //spec: not to update reasonPhrase (it is up to error handler if any)
        handler = _router.getErrorHandlerByCode(code);
        if (handler == null) {
          //TODO: render a page
          _close(connect);
          return;
        }
      }

      (handler is Function ?
        _ensureFuture(handler(connect), true): forward(connect, handler))
      .then((_) {
        _close(connect);
      }).catchError((err) {
        if (!shouted)
          _shout(connect, error, stackTrace);
        _shout(connect, "Unable to handle the error with $handler. Reason: $err");
        _close(connect);
      });
    } catch (e) {
      _close(connect);
    }
  }
  void _shout(HttpConnect connect, err, [st]) {
    final buf = new StringBuffer();
    if (connect != null)
      buf..write("(")..write(connect.request.uri)..write(") ");
    buf.write(err);
    if (st != null)
      buf..write("\n")..write(st);
    logger.shout(buf.toString());
  }
  void _close(HttpConnect connect) {
    connect.response.close();
      //no need to catch since close() is asynchronous
  }

  @override
  String get homeDir => _homeDir;
  @override
  final List<String> indexNames = ['index.html'];

  @override
  int get sessionTimeout => _sessTimeout;
  @override
  void set sessionTimeout(int timeout) {
    _sessTimeout = timeout;
    for (final _Channel channel in channels)
      channel._iserver.sessionTimeout = _sessTimeout;
  }

  @override
  bool chunkedTransferEncoding = true;

  @override
  String get uriVersionPrefix => _uriVerPrefix;
  @override
  void set uriVersionPrefix(String prefix) {
    if (prefix.isEmpty || (prefix.startsWith("/") && !prefix.endsWith("/")))
      _uriVerPrefix = prefix;
    else
      throw new ArgumentError("must be empty or start with /: $prefix");
  }
  String _uriVerPrefix = "";

  @override
  ResourceLoader get resourceLoader => _resLoader;
  void set resourceLoader(ResourceLoader loader) {
    if (loader == null)
      throw new ArgumentError("null");
    _resLoader = loader;
  }

  @override
  void onError(void handler(HttpConnect connect, err, [stackTrace])) {
    _onError = handler;
  }

  @override
  bool get isRunning => !_channels.isEmpty;
  @override
  Future<Channel> start({address, int port: 8080, int backlog: 0}) {
    if (address == null)
      address = InternetAddress.ANY_IP_V4;
    return HttpServer.bind(address, port, backlog: backlog)
    .catchError((err) {
      _handleErr(null, err);
    })
    .then((iserver) {
      final channel = new _HttpChannel(this, iserver, address, iserver.port, false);
      _startChannel(channel);
      _logHttpStarted(channel);
      return channel;
    });
  }
  @override
  Future<Channel> startSecure({address, int port: 8080, 
      String certificateName, bool requestClientCertificate: false,
      int backlog: 0}) {
    if (address == null)
      address = InternetAddress.ANY_IP_V4;
    return HttpServer.bindSecure(address, port, certificateName: certificateName,
        requestClientCertificate: requestClientCertificate, backlog: backlog)
    .catchError((err) {
      _handleErr(null, err);
    })
    .then((iserver) {
      final channel = new _HttpChannel(this, iserver, address, iserver.port, true);
      _startChannel(channel);
      _logHttpStarted(channel);
      return channel;
    });
  }
  void _logHttpStarted(HttpChannel channel) {
    final address = channel.address, port = channel.port;
    logger.info(
      "Rikulo Stream Server $version starting${channel.isSecure ? ' HTTPS': ''} on "
      "${address is InternetAddress ? (address as InternetAddress).address: address}:$port\n"
      "Home: ${homeDir}");
  }
  @override
  Channel startOn(ServerSocket socket) {
    final channel = new _SocketChannel(this, new HttpServer.listenOn(socket), socket);
    _startChannel(channel);
    logger.info("Rikulo Stream Server $version starting on $socket\n"
      "Home: ${homeDir}");
    return channel;
  }
  void _startChannel(_Channel channel) {
    final serverInfo = "Stream/$version";
    channel._iserver
    ..sessionTimeout = sessionTimeout
    ..listen((HttpRequest req) {
      (req = _unVersionPrefix(req, uriVersionPrefix)).response.headers
        ..set(HttpHeaders.SERVER, serverInfo)
        ..date = new DateTime.now();

      //protect from aborted connection
      final connect = new _HttpConnect(channel, req, req.response);
      req.response.done.catchError((err) {
        if (err is SocketException)
          logger.fine("${connect.request.uri}: $err"); //nothing to do
        else
          _handleErr(connect, err);
      });

      //TODO: use runZoned if it is available (then we don't need try/catch
      //in _handle and _handleErr)

      _handle(connect, 0).then((_) { //0 means filter from beginning
        _close(connect);
      }).catchError((err) {
        _handleErr(connect, err);
      });
    }, onError: (err) {
      _handleErr(null, err);
    });
  }
  @override
  void stop() {
    if (!isRunning)
      throw new StateError("Not running");
    for (final Channel channel in new List.from(channels))
      channel.close();
  }

  @override
  void map(String uri, handler, {preceding: false}) {
    _router.map(uri, handler, preceding: preceding);
  }
  @override
  void filter(String uri, RequestFilter filter, {preceding: false}) {
    _router.filter(uri, filter, preceding: preceding);
  }

  @override
  List<Channel> get channels => _channels;

  Future _ensureFuture(value, [bool ignoreFutureOnly=false]) {
    //Note: we can't use Http500. otherwise, the error won't be logged
    if (value == null) { //immediate (no async task)
      if (_futureOnly && !ignoreFutureOnly)
        throw new ServerError("Handler/filter must return Future");
      return new Future.value();
    }
    if (value is Future)
      return value;
    throw new ServerError("Handler/filter must return null or Future, not $value");
  }
}

///A channel.
abstract class _Channel implements Channel {
  final HttpServer _iserver;
  @override
  final StreamServer server;
  @override
  final DateTime startedSince;

  bool _closed = false;

  _Channel(this.server, this._iserver): startedSince = new DateTime.now();

  @override
  HttpConnectionsInfo get connectionsInfo => _iserver.connectionsInfo();
  @override
  void close() {
    _closed = true;
    _iserver.close();

    final List<Channel> channels = server.channels;
    for (int i = channels.length; --i >= 0;)
      if (identical(this, channels[i])) {
        channels.removeAt(i);
        break;
      }
  }
  @override
  bool get isClosed => _closed;
}

class _HttpChannel extends _Channel implements HttpChannel {
  final address;
  final int port;
  final bool isSecure;

  _HttpChannel(StreamServer server, HttpServer iserver, this.address, this.port,
      this.isSecure): super(server, iserver);
}

class _SocketChannel extends _Channel implements SocketChannel {
  final ServerSocket socket;

  _SocketChannel(StreamServer server, HttpServer iserver, this.socket):
      super(server, iserver);
}

HttpRequest _unVersionPrefix(HttpRequest req, String prefix) {
  String path;
  return !prefix.isEmpty && (path = req.uri.path).startsWith(prefix) ?
    _wrapRequest(req, path.substring(prefix.length), keepQuery: true): req;
}
