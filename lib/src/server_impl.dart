//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Mar 12, 2013  7:08:29 PM
// Author: tomyeh
part of stream;

class _StreamServer implements StreamServer {
  final String version = "0.7.0";
  HttpServer _server;
  String _host = "127.0.0.1";
  int _port = 8080;
  int _sessTimeout = 20 * 60; //20 minutes
  final Logger logger;
  Path _homeDir;
  ResourceLoader _resLoader;
  final Router _router;
  ConnectErrorCallback _defaultErrorCallback, _onError;

  _StreamServer(Router router, String homeDir, LoggingConfigurer loggingConfigurer):
      _router = router, logger = new Logger("stream") {
    (loggingConfigurer != null ? loggingConfigurer: new LoggingConfigurer())
      .configure(logger);
    _init();
    _initDir(homeDir);
  }

  void _init() {
    _defaultErrorCallback = (HttpConnect cnn, err, [st]) {
      _handleErr(cnn, err, st);
    };
  }
  void _initDir(String homeDir) {
    var path;
    if (homeDir != null) {
      path = new Path(homeDir);
    } else {
      homeDir = new Options().script;
      path = homeDir != null ? new Path(homeDir).directoryPath: new Path("");
    }

    if (!path.isAbsolute)
      path = new Path(new Directory.current().path).join(path);

    //look for webapp
    for (final orgpath = path;;) {
      final nm = path.filename;
      path = path.directoryPath;
      if (nm == "webapp")
        break; //found and we use its parent as homeDir
      final ps = path.toString();
      if (ps.isEmpty || ps == "/")
        throw new ServerError(
          "The application must be under the webapp directory, not ${orgpath.toNativePath()}");
    }

    _homeDir = path;
    if (!new Directory.fromPath(_homeDir).existsSync())
      throw new ServerError("$homeDir doesn't exist.");
    _resLoader = new ResourceLoader(_homeDir);
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
      _shout(error, stackTrace);
      return;
    }

    try {
      if (_onError != null)
        _onError(connect, error, stackTrace);
      if (connect.errorDetail != null) { //called twice; ignore 2nd one
        _shout(error, stackTrace);
        return; //done
      }

      connect.errorDetail = new ErrorDetail(error, stackTrace);
      var handler = _router.getErrorHandler(error);
      if (handler == null) {
        if (error is! HttpStatusException) {
          _shout(error, stackTrace);
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

      (handler is Function ? _ensureFuture(handler(connect)):
        forward(connect, handler)).then((_) {
        _close(connect);
      }).catchError((err) {
        _shout("Unable to handle the error. Reason: $err");
        _close(connect);
      });
    } catch (e) {
      _close(connect);
    }
  }
  void _shout(err, [st]) {
    logger.shout(st != null ? "$err:\n$st": "$err");
  }
  void _close(HttpConnect connect) {
    connect.response.close();
      //no need to catch since close() is asynchronous
  }

  @override
  Path get homeDir => _homeDir;
  @override
  final List<String> indexNames = ['index.html'];

  @override
  int get port => _port;
  @override
  void set port(int port) {
    _assertIdle();
    _port = port;
  }
  @override
  String get host => _host;
  @override
  void set host(String host) {
    _assertIdle();
    _host = host;
  }
  @override
  int get sessionTimeout => _sessTimeout;
  @override
  void set sessionTimeout(int timeout) {
    _sessTimeout = timeout;
    if (_server != null)
      _server.sessionTimeout = _sessTimeout;
  }

  @override
  ResourceLoader get resourceLoader => _resLoader;
  void set resourceLoader(ResourceLoader loader) {
    if (loader == null)
      throw new ArgumentError("null");
    _resLoader = loader;
  }

  @override
  void onError(ConnectErrorCallback onError) {
    _onError = onError;
  }
  @override
  ConnectErrorCallback get defaultErrorCallback => _defaultErrorCallback;

  @override
  bool get isRunning => _server != null;
  @override
  Future<StreamServer> start({int backlog: 0}) {
    _assertIdle();
    return HttpServer.bind(host, port, backlog)
    .catchError((err) {
      _handleErr(null, err);
    })
    .then((server) {
      _server = server;
      _startServer();
      logger.info("Rikulo Stream Server $version starting on $host:$port\n"
        "Home: ${homeDir}");
      return this;
    });
  }
  @override
  Future<StreamServer> startSecure({String certificateName, bool requestClientCertificate: false,
    int backlog: 0}) {
    _assertIdle();
    return HttpServer.bindSecure(host, port, certificateName: certificateName,
        requestClientCertificate: requestClientCertificate, backlog: backlog)
    .catchError((err) {
      _handleErr(null, err);
    })
    .then((server) {
      _server = server;
      _startServer();
      logger.info("Rikulo Stream Server $version starting on $host:$port for HTTPS\n"
        "Home: ${homeDir}");
      return this;
    });
  }
  @override
  void startOn(ServerSocket socket) {
    _assertIdle();
    _server = new HttpServer.listenOn(socket);
    _startServer();
    logger.info("Rikulo Stream Server $version starting on $socket\n"
      "Home: ${homeDir}");
  }
  void _startServer() {
    final serverInfo = "Rikulo Stream $version";
    _server.sessionTimeout = sessionTimeout;
    _server.listen((HttpRequest req) {
      req.response.headers
        ..add(HttpHeaders.SERVER, serverInfo)
        ..date = new DateTime.now();

      //protect from aborted connection
      final connect = new _HttpConnect(this, req, req.response);
      req.response.done.catchError((err) {
        if (err is SocketIOException)
          logger.fine("${connect.request.uri}: $err"); //nothing to do
        else
          _handleErr(connect, err);
      });

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
    if (_server == null)
      throw new StateError("Not running");
    _server.close();
    _server = null;
  }
  void _assertIdle() {
    if (_server != null)
      throw new StateError("Already running");
  }

  @override
  void map(String uri, handler, {preceding: false}) {
    _router.map(uri, handler, preceding: preceding);
  }
  @override
  void filter(String uri, RequestFilter filter, {preceding: false}) {
    _router.filter(uri, filter, preceding: preceding);
  }
}

Future _ensureFuture(value) {
  if (value == null) //immediate (no async task)
    return new Future.value();
  if (value is Future)
    return value;
  throw new Http500("The handler must return null or Future, not $value");
}
