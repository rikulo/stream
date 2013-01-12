//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Jan 08, 2013 12:08:05 PM
// Author: tomyeh
part of stream;

/** The error handler. */
typedef void ErrorHandler(e);
/** The error handler for HTTP connection. */
typedef void ConnexErrorHandler(HttpConnex connex, e);

/**
 * Stream server.
 */
abstract class StreamServer {
  factory StreamServer({Map<String, Function> urlMapping, String homeDir,
    LoggingConfigurer loggingConfigurer, bool debug: true})
  => new _StreamServer(urlMapping, homeDir, loggingConfigurer, debug);

  /** The path of the home directory.
   */
  final Path homeDir;
  /** A list of names that will be used to locate the resource if
   * the given path is a directory.
   *
   * Default: `[index.html]`
   */
  final List<String> indexNames;

  /** The port. Default: 8080.
   */
  int port;
  /** The host. Default: "127.0.0.1".
   */
  String host;

  /** The timeout, in seconds, for sessions of this server.
   * Default: 1200 (unit: seconds)
   */
  int sessionTimeout;

  /** Indicates whether the server is running.
   */
  final bool isRunning;
  /** Starts the server
   *
   * If [serverSocket] is given (not null), it will be used ([host] and [port])
   * will be ignored. In additions, the socket won't be closed when the
   * server stops.
   */
  void run([ServerSocket socket]);
  /** Stops the server.
   */
  void stop();

  /** The resource loader used to load the static resources.
   * It is called if the path of a request doesn't match any of the URL
   * mapping given in the constructor.
   */
  ResourceLoader resourceLoader;
  /** The logger for logging information.
   * The default level is `INFO`.
   */
  final Logger logger;
  /** Whether to show the debugging information. Default: true.
   */
  bool debug;
}
/** A generic server error.
 */
class ServerError implements Error {
  final String message;

  ServerError(String this.message);
  String toString() => "ServerError($message)";
}

/** A safe invocation of `Future.then(onValue)`. It will invoke `connex.error(e)`
 * automatically if there is an exception.
 * It is strongly suggested to use this method instead of calling `then` directly
 * when handling an request asynchronously. For example,
 *
 *     safeThen(file.exists, connex, (exists) {
 *       if (exists)
 *           doSomething(); //any exception will be caught and handled
 *       throw new Http404();
 *     }
 */
void safeThen(Future future, HttpConnex connex, onValue(value)) {
  future.then((value) {
    try {
      onValue(value);
    } catch (e) {
      connex.error(e);
    }
  }/*, onError: connex.error*/); //TODO: wait for next SDK
}

///The implementation
class _StreamServer implements StreamServer {
  final String version = "0.1.0";
  final HttpServer _server;
  String _host = "127.0.0.1";
  int _port = 8080;
  int _sessTimeout = 20 * 60; //20 minutes
  final Logger logger;
  Path _homeDir;
  ResourceLoader _resLoader;
  ConnexErrorHandler _cxerrh;
  bool _running = false, debug;

  _StreamServer(Map<String, Function> urlMapping, String homeDir,
    LoggingConfigurer loggingConfigurer, bool this.debug)
    : _server = new HttpServer(), logger = new Logger("stream") {
    (loggingConfigurer != null ? loggingConfigurer: new LoggingConfigurer())
      .configure(logger);
    _init();
    _initDir(homeDir);
    _initMapping(urlMapping);
  }
  void _init() {
    _cxerrh = (HttpConnex cnn, e) {
      _handleError(cnn, e);
    };
    _server.defaultRequestHandler =
      (HttpRequest req, HttpResponse res) {
        _handle(new _HttpConnex(this, req, res, _cxerrh), req.uri);
      };
    _server.onError = (e) {
      _handleError(null, e);
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
      path = new Path.fromNative(new Directory.current().path).join(path);

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
  void _initMapping(Map<String, Function> mapping) {
    if (mapping != null)
      ; //TODO
  }

  /** Forward the given [connex] to the given [uri].
   *
   * If [request] or [response] is ignored, [connex] is assumed.
   */
  void forward(HttpConnex connex, String uri,
    {HttpRequest request, HttpResponse response}) {
    _handle(new _ForwardedConnex(connex, request, response, _cxerrh), uri);
  }
  void _handle(HttpConnex connex, String uri) {
    try {
      if (!uri.startsWith('/')) uri = "/$uri";

      //TODO: handle url mapping

      //protect from access
      if (connex.forwarder == null &&
      (uri.startsWith("/webapp/") || uri == "/webapp"))
        throw new Http403(uri);

      resourceLoader.load(connex, uri);
    } catch (e) {
      _handleError(connex, e);
    }
  }
  void _handleError(HttpConnex connex, error) {
    //TODO
    if (connex != null) {
      if (!connex.isError) {
        connex.isError = true;
        try {
          connex.response.outputStream.close();
        } catch (e) { //silent
        }

        logger.shout(error);
      }
    } else {
      logger.shout(error);
    }
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
    _sessTimeout = _server.sessionTimeout = timeout;
  }

  @override
  ResourceLoader get resourceLoader => _resLoader;
  void set resourceLoader(ResourceLoader loader) {
    if (loader == null)
      throw new ArgumentError("null");
    _resLoader = loader;
  }

  @override
  bool get isRunning => _running;
  //@override
  void run([ServerSocket socket]) {
    _assertIdle();
    if (socket != null)
      _server.listenOn(socket);
    else
      _server.listen(host, port);

    logger.info("Rikulo Stream Server $version starting on "
      "${socket != null ? '$socket': '$host:$port'}\n"
      "Home: ${homeDir}");
  }
  //@override
  void stop() {
    _server.close();
  }
  void _assertIdle() {
    if (isRunning)
      throw new StateError("Already running");
    _server.close();
  }
}
