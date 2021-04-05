//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Mar 12, 2013  7:08:29 PM
// Author: tomyeh
part of stream;

const String _version = version.version;
const String _serverHeader = "Stream/$_version";

///The error handler for HTTP connection.
typedef void _ConnectErrorCallback(HttpConnect? connect, error, StackTrace? stackTrace);
///The callback of onIdle
typedef void _OnIdleCallback();
///The callback of countConnection
typedef bool _ShallCount(HttpConnect connect);

class _StreamServer implements StreamServer {
  @override
  final String version = _version;
  @override
  final Logger logger;

  final List<HttpChannel> _channels = [];
  int _sessTimeout = 20 * 60; //20 minutes
  final Router _router;
  _ConnectErrorCallback? _onError;
  _OnIdleCallback? _onIdle;
  _ShallCount? _shallCount;
  int _connectionCount = 0;

  factory _StreamServer(Router router, String? homeDir, bool disableLog) {
    homeDir = homeDir == null ? _getRootPath():
      Path.isAbsolute(homeDir) ? homeDir: Path.join(_getRootPath(), homeDir);

    if (!new Directory(homeDir).existsSync())
      throw new ServerError("$homeDir doesn't exist.");

    final logger = new Logger("stream");
    if (!disableLog) {
      Logger.root.level = Level.INFO;
      logger.onRecord.listen(simpleLoggerHandler);
    }
    return _StreamServer._(router, homeDir, new ResourceLoader(homeDir), logger);
  }
  _StreamServer._(this._router, this.homeDir, this.resourceLoader, this.logger);

  static String _getRootPath() {
    String path;
    try {
      path = Path.absolute(Path.normalize(Path.dirname(
          Platform.script.toFilePath())));
    } catch (_) { //UnsupportedError if running from IDE
      path = Path.current;
    }

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
    HttpRequest? request, HttpResponse? response})
  => _handle(new HttpConnect.chain(connect, inclusion: false,
      uri: uri, request: request, response: response)) ?? new Future.value(); //no filter invocation
    //spec: for easy use, forward/include won't never return null
  @override
  Future include(HttpConnect connect, String uri, {
    HttpRequest? request, HttpResponse? response})
  => _handle(new HttpConnect.chain(connect, inclusion: true,
      uri: uri, request: request, response: response)) ?? new Future.value(); //no filter invocation
    //spec: for easy use, forward/include won't never return null

  /// [iFilter] - the index of filter to start. It must be non-negative.
  /// Ignored if null.
  /// 
  /// Note: it might return null (if app's handler returns null)
  Future? _handle(HttpConnect connect, [int? iFilter]) {
    String uri = connect.request.uri.path;
    if (!uri.startsWith('/'))
      uri = "/$uri"; //not possible; just in case

    if (iFilter != null) { //null means ignore filters
      iFilter = _router.getFilterIndex(connect, uri, iFilter);
      if (iFilter != null) { //found
        final i = iFilter;
        return _router.getFilterAt(iFilter)(connect,
          (conn) => _handle(conn, i + 1) ?? new Future.value());
      }
    }

    var handler = _router.getHandler(connect, uri);
    if (handler != null) {
      if (handler is Function)
        return handler(connect) as Future?;

      final target = handler as String;
      if (_completeUriRegex.hasMatch(target)) {
        connect.redirect(target);
        return null;
      } else {
        return forward(connect, target);
      }
    }

    //protect from access
    if (!connect.isForwarded && !connect.isIncluded &&
    (uri.startsWith("/webapp/") || uri == "/webapp"))
      throw new Http403(uri: Uri.tryParse(uri));

    String path;
    try {
      path = Uri.decodeComponent(uri);
    } catch (_) {
      throw new Http404.fromConnect(connect);
    }

    return resourceLoader.load(connect, path);
  }
  Future _handleErr(HttpConnect connect, error, StackTrace stackTrace) async {
    if (connect.errorDetail != null) { //called twice; ignore 2nd one
      _logError(connect, error, stackTrace);
      return; //done
    }

    bool shouted = false;
    connect.errorDetail = new ErrorDetail(error, stackTrace);

    var handler = _router.getErrorHandler(error);
    if (handler == null) {
      if (error is! HttpStatusException) {
        _logError(connect, error, stackTrace);
        shouted = true;
        error = new Http500.fromConnect(connect,
            cause: error != null ? error.toString(): "");
      }

      final code = error.statusCode;
      try {
        connect.response.statusCode = code;
          //spec: not to update reasonPhrase (it is up to error handler if any)
      } catch (ex, st) { //possible: Header already sent
        _logError(connect, ex, st);
      }

      handler = _router.getErrorHandler(code);
      if (handler == null) return;
    }

    try {
      await (handler is Function ? handler(connect):
        forward(connect, handler as String));
    } catch (ex, st) {
      if (!shouted)
        _logError(connect, error, stackTrace);
      _logError(connect, ex, st);
    }
  }

  void _logInitError(error, StackTrace stackTrace)
  => _logError(null, error, stackTrace);

  void _logError(HttpConnect? connect, error, [StackTrace? stackTrace]) {
    final onError = _onError;
    if (onError != null) {
      try {
        onError(connect, error, stackTrace);
      } catch (ex, st) {
        _shout(connect, error, stackTrace);
        _shout(connect, ex, st);
      }
    } else {
      _shout(connect, error, stackTrace);
    }
  }

  void _shout(HttpConnect? connect, err, [StackTrace? st]) {
    final buf = new StringBuffer();
    try {
      buf..write(new DateTime.now())..write(':');

      if (connect != null) {
        buf..write("[")..write(connect.request.uri.path)..write("] ");

        final values = connect.request.headers[HttpHeaders.userAgentHeader];
        if (values != null && values.length >= 1) buf..writeln(values[0]);
      }

      buf..write(err);
      if (st != null)
        buf..write("\n")..write(st);
      logger.shout(buf.toString());

    } catch (_) {
      if (buf.isEmpty) {
        print(err);
        if (st != null)
          print(st);
      } else {
        print(buf);
      }
    }
  }

  @override
  final String homeDir;
  @override
  final List<String> indexNames = ['index.html'];

  @override
  int get sessionTimeout => _sessTimeout;
  @override
  void set sessionTimeout(int timeout) {
    _sessTimeout = timeout;
    for (final channel in channels)
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
  PathPreprocessor? pathPreprocessor;

  @override
  ResourceLoader resourceLoader;

  @override
  void onError(void onError(HttpConnect? connect, error, StackTrace? stackTrace)) {
    _onError = onError;
  }
  @override
  void onIdle(void onIdle()?) {
    _onIdle = onIdle;
  }
  @override
  int get connectionCount => _connectionCount;
  @override
  void set shallCount(bool shallCount(HttpConnect connect)?) {
    _shallCount = shallCount;
  }

  @override
  bool get isRunning => !_channels.isEmpty;
  @override
  Future<HttpChannel> start({address, int port: 8080, int backlog: 0,
      bool v6Only: false, bool shared: false, bool zoned: true}) async {
    if (address == null)
      address = InternetAddress.anyIPv4;

    final iserver = await HttpServer.bind(address, port, backlog: backlog,
        v6Only: v6Only, shared: shared);

    final channel = new _HttpChannel(this, iserver, address, iserver.port, false);
    _startChannel(channel, zoned);
    _logHttpStarted(channel);
    return channel;
  }
  @override
  Future<HttpChannel> startSecure(SecurityContext context,
      {address, int port: 8443,
      bool v6Only: false, bool requestClientCertificate: false,
      int backlog: 0, bool shared: false, bool zoned: true}) async {
    if (address == null)
      address = InternetAddress.anyIPv4;

    final iserver = await HttpServer.bindSecure(address, port, context,
        requestClientCertificate: requestClientCertificate,
        backlog: backlog, v6Only: v6Only, shared: shared);

    final channel = new _HttpChannel(this, iserver, address, iserver.port, true);
    _startChannel(channel, zoned);
    _logHttpStarted(channel);
    return channel;
  }
  void _logHttpStarted(HttpChannel channel) {
    final address = channel.address, port = channel.port;
    logger.info(
      "Rikulo Stream Server $_version starting${channel.isSecure ? ' HTTPS': ''} on "
      "${address is InternetAddress ? address.address: address}:$port\n"
      "Home: ${homeDir}");
  }
  @override
  HttpChannel startOn(ServerSocket socket, {bool zoned: true}) {
    final channel = new _HttpChannel.fromSocket(
        this, new HttpServer.listenOn(socket), socket);
    _startChannel(channel, zoned);
    logger.info("Rikulo Stream Server $_version starting on $socket\n"
      "Home: ${homeDir}");
    return channel;
  }

  void _startChannel(_HttpChannel channel, bool zoned) {
    if (zoned) {
      runZonedGuarded(() =>_startNow(channel), _logInitError);
    } else {
      _startNow(channel);
    }
  }
  void _startNow(_HttpChannel channel) {
    channel.httpServer
    ..sessionTimeout = sessionTimeout
    ..listen((HttpRequest req) async {
      (req = _preprocess(req)).response.headers
        ..set(HttpHeaders.serverHeader, _serverHeader)
        ..date = new DateTime.now();

      //protect from aborted connection
      final connect = new _HttpConnect(channel, req, req.response),
        shallCount = _shallCount?.call(connect) != false;
      if (shallCount) ++_connectionCount;

      try {
        await _handle(connect, 0); //0 means filter from beginning
      } catch (ex, st) {
        try {
          await _handleErr(connect, ex, st);
        } catch (ex, st) {
          _logError(connect, ex, st);
        }
      } finally {
        try {
          if (connect.autoClose)
            await connect.response.close();
        } catch (ex, st) {
          _logError(connect, ex, st);
        } finally {
          if (shallCount && --_connectionCount <= 0) {
            assert(_connectionCount == 0);
            final onIdle = _onIdle;
            if (onIdle != null) {
              try {
                onIdle();
              } catch (ex, st) {
                _logError(connect, ex, st);
              }
            }
          }
        }
      }
    }, onError: _logInitError);
    _channels.add(channel);
  }

  HttpRequest _preprocess(HttpRequest req) {
    final path = req.uri.path,
      np = (pathPreprocessor ?? _defaultPathPreprocess)(path);
    return path == np ? req: _wrapRequest(req, np, keepQuery: true);
  }
  String _defaultPathPreprocess(String path) {
    return _uriVerPrefix.isNotEmpty && path.startsWith(_uriVerPrefix) ?
        path.substring(_uriVerPrefix.length): path;
  }

  @override
  Future stop() {
    if (!isRunning)
      throw new StateError("Not running");
    final ops = <Future>[];
    for (int i = channels.length; --i >= 0;)
      ops.add(channels[i].close());
    return Future.wait(ops);
  }

  @override
  void map(String uri, handler, {bool preceding: false}) {
    _router.map(uri, handler, preceding: preceding);
  }
  @override
  void filter(String uri, RequestFilter filter, {bool preceding: false}) {
    _router.filter(uri, filter, preceding: preceding);
  }

  @override
  List<HttpChannel> get channels => _channels;
}
