//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Mar 12, 2013  7:08:29 PM
// Author: tomyeh
part of stream;

const String _VERSION = "1.5.2";
const String _SERVER_HEADER = "Stream/$_VERSION";

///The error handler for HTTP connection.
typedef void _ConnectErrorCallback(HttpConnect connect, err, [stackTrace]);
///The callback of onIdle
typedef void _OnIdleCallback();

class _StreamServer implements StreamServer {
  @override
  final String version = _VERSION;
  @override
  final Logger logger;

  final List<HttpChannel> _channels = [];
  int _sessTimeout = 20 * 60; //20 minutes
  String _homeDir;
  ResourceLoader _resLoader;
  final Router _router;
  _ConnectErrorCallback _onError;
  _OnIdleCallback _onIdle;
  int _connectionCount = 0;
  final bool _futureOnly;

  _StreamServer(this._router, String homeDir, bool disableLog,
    this._futureOnly): logger = new Logger("stream") {
    if (!disableLog) {
      Logger.root.level = Level.INFO;
      logger.onRecord.listen(simpleLoggerHandler);
    }

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
    String path = Platform.script.toFilePath();
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
  void _handleErr(HttpConnect connect, error, stackTrace) {
    try {
      if (_onError != null) {
        try {
          _onError(connect, error, stackTrace);
        } catch (err, st) {
          _shout(connect, _errorToString(err, st));
        }
      }

      if (connect == null) {
        _shout(null, "Uncaught " + _errorToString(error, stackTrace));
        return;
      }

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
          error = new Http500.fromConnect(connect,
            error != null ? error.toString(): "");
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
      })
      .catchError((err, st) {
        if (!shouted)
          _shout(connect, error, stackTrace);
        _shout(connect, _errorToString(err, st));
        _close(connect);
      });
    } catch (err, st) {
      _shout(connect, _errorToString(err, st));
      if (connect != null)
        _close(connect);
    }
  }

  static String _errorToString(err, st) => st != null ? "$err\n$st": "$err";

  void _shout(HttpConnect connect, err, [st]) {
    final StringBuffer buf = new StringBuffer();
    try {
      if (connect != null) {
        final String uri = connect.request.uri.path;
        buf..write("[")..write(uri)..write("] ");
      }
      buf..write(err);
      if (st != null)
        buf..write("\n")..write(st);
      logger.shout(buf.toString());

    } catch (e) {
      if (buf.isEmpty) {
        print(err);
        if (st != null)
          print(st);
      } else {
        print(buf);
      }
    }
  }
  void _close(HttpConnect connect) {
    try {
      connect.response.close();
        //no need to catch since close() is asynchronous
    } finally {
      if (--_connectionCount == 0 && _onIdle != null) {
        try {
          _onIdle();
        } catch (err, st) {
          _shout(connect, _errorToString(err, st));
        }
      }
    }
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
    for (final _HttpChannel channel in channels)
      channel.httpServer.sessionTimeout = _sessTimeout;
  }

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
  void onError(void onError(HttpConnect connect, err, [stackTrace])) {
    _onError = onError;
  }
  @override
  void onIdle(void onIdle()) {
    _onIdle = onIdle;
  }
  @override
  int get connectionCount => _connectionCount;

  @override
  bool get isRunning => !_channels.isEmpty;
  @override
  Future<HttpChannel> start({address, int port: 8080,
      int backlog: 0, bool zoned: true}) {
    if (address == null)
      address = InternetAddress.ANY_IP_V4;
    return HttpServer.bind(address, port, backlog: backlog)
    .then((HttpServer iserver) {
      final channel = new _HttpChannel(this, iserver, address, iserver.port, false);
      _startChannel(channel, zoned);
      _logHttpStarted(channel);
      return channel;
    });
  }
  @override
  Future<HttpChannel> startSecure({address, int port: 8443, 
      String certificateName, bool requestClientCertificate: false,
      int backlog: 0, bool zoned: true}) {
    if (address == null)
      address = InternetAddress.ANY_IP_V4;
    return HttpServer.bindSecure(address, port, certificateName: certificateName,
        requestClientCertificate: requestClientCertificate, backlog: backlog)
    .then((HttpServer iserver) {
      final channel = new _HttpChannel(this, iserver, address, iserver.port, true);
      _startChannel(channel, zoned);
      _logHttpStarted(channel);
      return channel;
    });
  }
  void _logHttpStarted(HttpChannel channel) {
    final address = channel.address, port = channel.port;
    logger.info(
      "Rikulo Stream Server $_VERSION starting${channel.isSecure ? ' HTTPS': ''} on "
      "${address is InternetAddress ? (address as InternetAddress).address: address}:$port\n"
      "Home: ${homeDir}");
  }
  @override
  HttpChannel startOn(ServerSocket socket, {bool zoned: true}) {
    final channel = new _HttpChannel.fromSocket(
        this, new HttpServer.listenOn(socket), socket);
    _startChannel(channel, zoned);
    logger.info("Rikulo Stream Server $_VERSION starting on $socket\n"
      "Home: ${homeDir}");
    return channel;
  }

  void _startChannel(_HttpChannel channel, bool zoned) {
    if (zoned) {
      runZoned(() {
        _startNow(channel);
      },
      onError: (err, stackTrace) {
        _handleErr(null, err, stackTrace);
      });
    } else {
      _startNow(channel);
    }
  }
  void _startNow(_HttpChannel channel) {
    channel.httpServer
    ..sessionTimeout = sessionTimeout
    ..listen((HttpRequest req) {
      (req = _unVersionPrefix(req, uriVersionPrefix)).response.headers
        ..set(HttpHeaders.SERVER, _SERVER_HEADER)
        ..date = new DateTime.now();

      ++_connectionCount;

      //protect from aborted connection
      final HttpConnect connect = new _HttpConnect(channel, req, req.response);
      _handle(connect, 0).then((_) { //0 means filter from beginning
        _close(connect);
      }).catchError((err, stackTrace) {
        _handleErr(connect, err, stackTrace);
      });
    });
    _channels.add(channel);
  }

  @override
  Future stop() {
    if (!isRunning)
      throw new StateError("Not running");
    final List<Future> ops = new List(channels.length);
    for (int i = channels.length; --i >= 0;)
      ops[i] = channels[i].close();
    return Future.wait(ops);
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
  List<HttpChannel> get channels => _channels;

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

HttpRequest _unVersionPrefix(HttpRequest req, String prefix) {
  String path;
  return !prefix.isEmpty && (path = req.uri.path).startsWith(prefix) ?
    _wrapRequest(req, path.substring(prefix.length), keepQuery: true): req;
}
