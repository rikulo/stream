//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Mar 12, 2013  7:08:29 PM
// Author: tomyeh
part of stream;

class _StreamServer implements StreamServer {
  final String version = "0.6.0";
  HttpServer _server;
  String _host = "127.0.0.1";
  int _port = 8080;
  int _sessTimeout = 20 * 60; //20 minutes
  final Logger logger;
  Path _homeDir;
  final List<_UriMapping> _uriMapping = [], _filterMapping = [];
  final Map<int, dynamic> _codeMapping = new HashMap(); //mapping of status code to URI/Function
  final List<_ErrMapping> _errMapping = []; //exception to URI/Function
  ResourceLoader _resLoader;
  ConnectErrorHandler _defaultErrorHandler, _onError;

  _StreamServer(Map<String, Function> uriMapping,
    Map errorMapping, Map<String, Filter> filterMapping,
    String homeDir, LoggingConfigurer loggingConfigurer): logger = new Logger("stream") {
    (loggingConfigurer != null ? loggingConfigurer: new LoggingConfigurer())
      .configure(logger);
    _init();
    _initDir(homeDir);
    _initMapping(uriMapping, errorMapping, filterMapping);
  }
  void _init() {
    _defaultErrorHandler = (HttpConnect cnn, err, [st]) {
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
  void _initMapping(Map<String, Function> uriMapping, Map errMapping, Map<String, Filter> filterMapping) {
    if (uriMapping != null)
      for (final uri in uriMapping.keys) {
        if (!uri.startsWith("/"))
          throw new ServerError("URI mapping: URI must start with '/': $uri");
        final hdl = uriMapping[uri];
        if (hdl is! Function)
          throw new ServerError("URI mapping: function is required for $uri");
        _uriMapping.add(new _UriMapping(uri, hdl));
      }

    //default mapping
    _uriMapping.add(new _UriMapping("/.*[.]rsp(|[.][^/]*)", _404));

    if (filterMapping != null)
      for (final uri in filterMapping.keys) {
        if (!uri.startsWith("/"))
          throw new ServerError("Filter mapping: URI must start with '/': $uri");
        final hdl = filterMapping[uri];
        if (hdl is! Function)
          throw new ServerError("Filter mapping: function is required for $uri");
        _filterMapping.add(new _UriMapping(uri, hdl));
      }

    if (errMapping != null)
      for (var code in errMapping.keys) {
        final handler = errMapping[code];
        if (handler is String) {
          if (!handler.startsWith("/"))
            throw new ServerError("Error mapping: URI must start with '/': $handler");
        } else if (handler is! Function) {
          throw new ServerError("Error mapping: URI or function is required for $code");
        }

        if (code is String) {
          try {
            if (StringUtil.isChar(code[0], digit:true))
              code = int.parse(code);
            else
              code = ClassUtil.forName(code);
          } catch (e) { //silent; handle it  later
          }
        } else if (code != null && code is! int) {
          code = reflect(code).type;
        }
        if (code is int)
          _codeMapping[code] = handler;
        else if (code is ClassMirror)
          _errMapping.add(new _ErrMapping(code, handler));
        else
          throw new ServerError("Error mapping: status code or exception is required, not $code");
      }
  }
  static final Function _404 = (_) => throw new Http404();

  @override
  void forward(HttpConnect connect, String uri, {Handler success,
    HttpRequest request, HttpResponse response}) {
    if (uri.indexOf('?') >= 0)
      throw new UnsupportedError("Forward with query string"); //TODO

    _handle(new _ForwardedConnect(connect, request, response, _toAbsUri(connect, uri))
      ..onClose.listen((_){
          if (success != null)
            success();
          connect.close(); //spec: it is the forwarded handler's job to close
        })); //no filter invocation
  }
  @override
  void include(HttpConnect connect, String uri, {Handler success,
    HttpRequest request, HttpResponse response}) {
    if (uri.indexOf('?') >= 0)
      throw new UnsupportedError("Include with query string"); //TODO
    _handle(connectForInclusion(
      connect, uri: uri, success: success, request: request, response: response));
      //no filter invocation
  }
  @override
  HttpConnect connectForInclusion(HttpConnect connect, {String uri, Handler success,
    HttpRequest request, HttpResponse response}) {
    final inc = new _IncludedConnect(connect, request, response,
        uri != null ? _toAbsUri(connect, uri): null);
    if (success != null)
      inc.onClose.listen((_) {success();});
    return inc;
  }
  String _toAbsUri(HttpConnect connect, String uri) {
    if (!uri.startsWith('/')) {
      final pre = connect.request.uri.path;
      final i = pre.lastIndexOf('/');
      if (i >= 0)
        uri = "${pre.substring(0, i + 1)}$uri";
      else
        uri = "/$uri";
    }
    return uri;
  }
  ///[iFilter] - the index of filter to start. It must be non-negative. Ignored if null.
  void _handle(HttpConnect connect, [int iFilter]) {
    try {
      String uri = connect.request.uri.path;
      if (!uri.startsWith('/'))
        uri = "/$uri"; //not possible; just in case

      if (iFilter != null) //null means ignore filters
        for (; iFilter < _filterMapping.length; ++iFilter)
          if (_filterMapping[iFilter].match(connect, uri)) {
            _filterMapping[iFilter].handler(connect, (HttpConnect conn) {
                _handle(conn, iFilter + 1);
              });
            return;
          }

      final hdl = _getHandler(connect, uri);
      if (hdl != null) {
        final ret = hdl(connect);
        if (ret is String)
          forward(connect, ret);
        return;
      }

      //protect from access
      if (!connect.isForwarded && !connect.isIncluded &&
      (uri.startsWith("/webapp/") || uri == "/webapp"))
        throw new Http403(uri);

      resourceLoader.load(connect, uri);
    } catch (e, st) {
      _handleErr(connect, e, st);
    }
  }
  Function _getHandler(HttpConnect connect, String uri) {
    //TODO: cache the matched result for better performance
    for (final mp in _uriMapping)
      if (mp.match(connect, uri))
        return mp.handler;
  }
  void _handleErr(HttpConnect connect, error, [stackTrace]) {
    while (error is AsyncError) {
      stackTrace = error.stackTrace;
      error = error.error;
    }

    if (connect == null) {
      _shout(error, stackTrace);
      return;
    }

    try {
      if (_onError != null)
        _onError(connect, error, stackTrace);
      if (connect.errorDetail != null) {
        _shout(error, stackTrace);
        _close(connect);
        return; //done
      }

      connect.errorDetail = new ErrorDetail(error, stackTrace);
      if (!_errMapping.isEmpty) {
        final caughtClass = reflect(error).type;
        for (final mapping in _errMapping) {
          if (ClassUtil.isAssignableFrom(mapping.error, caughtClass)) { //found
            _forwardDyna(connect, mapping.handler);
            return;
          }
        }
      }

      if (error is! HttpStatusException) {
        _shout(error, stackTrace);
        error = new Http500(error);
      }

      final code = error.statusCode;
      connect.response
        ..statusCode = code
        ..reasonPhrase = error.message;
      final handler = _codeMapping[code];
      if (handler != null) {
        _forwardDyna(connect, handler);
      } else {
        //TODO: render a page
        _close(connect);
      }
    } catch (e) {
      _close(connect);
    }
  }
  ///forward to URI or a render function
  void _forwardDyna(HttpConnect connect, handler) {
    if (handler is Function)
      handler(connect);
    else
      forward(connect, handler);
  }
  void _shout(err, st) {
    logger.shout(st != null ? "$err:\n$st": err);
  }
  void _close(HttpConnect connect) {
    try {
      connect.response.close();
    } catch (e) { //silent
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
  void onError(ConnectErrorHandler onError) {
    _onError = onError;
  }
  @override
  ConnectErrorHandler get defaultErrorHandler => _defaultErrorHandler;

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
      _handle(
        new _HttpConnect(this, req, req.response)
          ..onClose.listen((_) {req.response.close();}), 0); //process filter from beginning
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
}

class _UriMapping {
  RegExp _ptn;
  Map<int, String> _groups;
  final Function handler;

  _UriMapping(String uri, this.handler) {
    uri = "^$uri\$"; //match the whole URI
    _groups = new HashMap();

    //parse grouping: ([a-zA-Z_-]+:regex)
    final sb = new StringBuffer();
    bool bracket = false;
    l_top:
    for (int i = 0, grpId = 0, len = uri.length; i < len; ++i) {
      switch (uri[i]) {
        case '\\':
          if (i + 1 < len) {
            sb.write('\\');
            ++i; //skip next
          }
          break;
        case '[':
          bracket = true;
          break;
        case ']':
          bracket = false;
          break;
        case '(':
          if (!bracket) {
            sb.write('(');

            //parse the name of the group, if any
            String nm;
            final nmsb = new StringBuffer();
            int j = i;
            for (;;) {
              if (++j >= len) {
                sb.write(nmsb);
                break l_top;
              }

              final cc = uri[j];
              if (StringUtil.isChar(cc, lower:true, upper:true, digit: true, match:"_."))
                nmsb.write(cc);
              else {
                if (cc == ':') {
                  nm = nmsb.toString();
                } else {
                  sb.write(nmsb);
                  --j;
                }
                break;
              }
            }

            //parse upto ')'
            int nparen = 1;
            while (++j < len) {
              final cc = uri[j];
              sb.write(cc);
              if (cc == ')' && --nparen <= 0)
                break;
              if (cc == '(')
                ++nparen;
              if (cc == '\\' && j + 1 < len)
                sb.write(uri[++j]); //skip next
            }
            i = j;

            if (nm != null)
              _groups[grpId] = nm;
            ++grpId;
            continue;
          }
          break;
      }
      sb.write(uri[i]);
    }

    if (_groups.isEmpty)
      _groups = null;
    _ptn = new RegExp(_groups != null ? sb.toString(): uri);
  }
  bool match(HttpConnect connect, String uri) {
    final m = _ptn.firstMatch(uri);
    if (m != null) {
      if (_groups != null)
        for (final key in _groups.keys)
          connect.dataset[_groups[key]] = m.group(key + 1);
      return true;
    }
    return false;
  }
}

class _ErrMapping {
  final ClassMirror error;
  final handler;
  _ErrMapping(this.error, this.handler);
}
