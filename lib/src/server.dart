//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Jan 08, 2013 12:08:05 PM
// Author: tomyeh
part of stream;

/// Used with [StreamServer.pathPreprocessor] for preprocessing the
/// request's path.
typedef String PathPreprocessor(String path);

/**
 * Stream server.
 *
 * ##Start a server serving static resources only
 *
 *     new StreamServer().start();
 *
 * ##Start a full-featured server
 *
 *     new StreamServer(uriMapping: { //URI mapping
 *         "/your-uri-in-regex": yourHandler
 *       }, errorMapping: { //Error mapping
 *         "404": "/webapp/404.html",
 *         "500": your500Handler,
 *         "yourLib.YourSecurityException": yourSecurityHandler
 *       }, filterMapping: {
 *         "/your-uri-in-regex": yourFilter
 *       }).start();
 *  )
 */
abstract class StreamServer {
  /** Constructor.
   *
   * ##Request Handlers
   *
   * A request handler is responsible for handling a request. It is mapped
   * to particular URI patterns with [uriMapping].
   *
   * The first argument of a handler must be [HttpConnect]. It can have optional
   * arguments. If it renders the response, it doesn't need to return anything
   * (i.e., `void`). If not, it shall return an URI (which is a non-empty string,
   * starting with * `/`) that the request shall be forwarded to.
   *
   * ##WebSocket Handling
   * 
   * To handle WebSockets, you can prefix the URI mapping with `'ws:'`,
   * and then implement a WebSocket handler. A WebSocket handler has a
   * single argument and the argument type must be [WebSocket]. For example,
   *
   *     new StreamServer(uriMapping: {
   *       "ws:/foo": (WebSocket socket) {
   *         socket.listen((event) {
   *           //event is the message sent by the client
   *           //you can handle it and return a message by use of socket.add()
   *         });
   *         return socket.done;
   *       },
   *     }).start();
   *
   * Note: The `ws:` prefix in the mapping table maps both "ws://" and "wss://".
   * 
   * ##Arguments
   *
   * * [homeDir] - the home directory for holding static resources. If not specified,
   * it is the root directory of the application.
   * You can specify a relative path relative to the root
   * directory. For example, you can create a directory called `static` to hold
   * the static resources, and then specify `static` as the home directory.
   *     > The root directory is assumed to the parent directory of the `webapp`
   *     > directory if it exists. Otherwise, it is assumed to be the directory where
   *     > the `main` Dart file is. For example, if you execute `dart /foo1/myapp.dart`,
   *     > the root is assumed to be `/foo1`. On the other hand, if executing
   *     > `dart /foo2/webapp/myapp.dart`, then the root is `/foo2`.
   * * [uriMapping] - a map of URI mappings, `<String uri, RequestHandler handler>`
   * or `<String uri, String forwardURI>`.
   * The key is a regular expression used to match the request URI. If you can name
   * a group by prefix with a name, such as `'/dead-link(info:.*)'`.
   * The value can be the handler for handling the request, or another URI that this request
   * will be forwarded to. If the value is a URI and the key has named groups, the URI can
   * refer to the group with `(the_group_name)`.
   * For example: `'/dead-link(info:.*)': '/new-link(info)'`.
   * * [filterMapping] - a map of filter mapping, `<String uri, RequestFilter filter>`.
   * The key is a regular expression used to match the request URI.
   * The signature of a filter is `void foo(HttpConnect connect, void chain(HttpConnect conn))`.
   * * [errorMapping] - a map of error mapping. The key can be a number, an instance of
   * exception, a string representing a number, or a string representing the exception class.
   * The value can be an URI or a renderer function. The number is used to represent a status code,
   * such as 404 and 500. The exception is used for matching the caught exception.
   * Notice that, if you specify the name of the exception to handle,
   * it must include the library name and the class name, such as `"stream.ServerError"`.
   * * [disableLog] - whether to disable logs.
   * If false (default), [Logger.root] will be set to [Level.INFO], and
   * a listener will be added [logger].
   */
  factory StreamServer({Map<String, dynamic> uriMapping,
      Map errorMapping, Map<String, RequestFilter> filterMapping,
      String homeDir, bool disableLog: false})
  => new _StreamServer(
      new DefaultRouter(uriMapping: uriMapping,
        errorMapping: errorMapping, filterMapping: filterMapping),
      homeDir, disableLog);

  /** Constructs a server with the given router.
   * It is used if you'd like to use your own router, rather than the default one.
   */
  factory StreamServer.router(Router router, {String homeDir,
      bool disableLog: false})
  => new _StreamServer(router, homeDir, disableLog);

  /** The version.
   */
  String get version;
  /** The path of the home directory. It is the directory that static resources
   * are loaded from.
   */
  String get homeDir;
  /** A list of names that will be used to locate the resource if
   * the given path is a directory.
   *
   * Default: `index.html`
   */
  List<String> get indexNames;

  /** The timeout, in seconds, for sessions of this server.
   * Default: 1200 (unit: seconds)
   */
  int sessionTimeout;

  /** The prefix used to denote a different version of JavaScript or Dart code,
   * such that the browser will reload the JavaScript files automatically.
   * It will be removed before the URI mapping and  it is not visible to
   * the request handler. For example, you can generate the JavaScript link as
   * follows in RSP:
   *
   *     <script src="[=connect.server.uriVersionPrefix]/js/init.js"></script>
   *
   * Then, no matter the value of [uriVersionPrefix], the file at `/js/init.js`
   * will always be loaded.
   *
   * > Default: "" (no special prefix at all). Notice the value must start
   * with `"/"`.
   *
   * ##Typical Use
   *
   * You usually assign a build number to it when the server is restarted:
   *
   *     server.uriVersionPrefix = "/$buildNumber";
   *
   * Then, the browser will reload the JavaScript code automatically each
   * time the build number is changed.
   *
   * You can prefix it to the image that depends on the build number too.
   */
  String uriVersionPrefix;
  /** Preprocessor that will be used to preprocess the path of each request,
   * if specified.
   * 
   * By default, it removes [uriVersionPrefix], if specified and found
   * in the request's path.
   * However, to really make [uriVersionPrefix] to work, you usuaully have
   * to provide a preprocessor to remove all possible prefixes (including
   * the current version and all previous versions).
   * After all, browsers with cached content might request a file with
   * an older version.
   */
  PathPreprocessor pathPreprocessor;

  /** Indicates whether the server is running.
   */
  bool get isRunning;
  /** Starts the server to handle the given channel.
   *
   * Notice that you can invoke [start], [startSecure] and [startOn] multiple
   * times to handle multiple channels:
   *
   *     new StreamServer()
   *       ..start(port: 80)
   *       ..startSecure(context, address: "11.22.33.44", port: 443);
   *
   * To know which channel a request is received, you can access
   * [HttpConnect.channel].
   *
   * * [address] - It can either be a [String] or an [InternetAddress].
   * Default: [InternetAddress.anyIPv4] (i.e., "0.0.0.0").
   * It will cause Stream server to listen all adapters
   * IP addresses using IPv4.
   *
   * * [port] - the port. Default: 8080.
   * If port has the value 0 an ephemeral port will be chosen by the system.
   * The actual port used can be retrieved using [HttpChannel.port].
   *
   * * [backlog] - specify the listen backlog for the underlying OS listen setup.
   * If backlog has the value of 0 (the default) a reasonable value will be chosen
   * by the system.
   * * [zoned] - whether to start the server within a zone (i.e., `runZoned()`)
   * Default: true.
   */
  Future<HttpChannel> start({address, int port: 8080, int backlog: 0,
    bool v6Only: false, bool shared: false, bool zoned: true});
  /** Starts the server listening for HTTPS request.
   *
   * Notice that you can invoke [start], [startSecure] and [startOn] multiple
   * times to handle multiple channels:
   *
   *     new StreamServer()
   *       ..start(port: 80)
   *       ..startSecure(context, address: "11.22.33.44", port: 443);
   *
   * To know which channel a request is received, you can access
   * [HttpConnect.channel].
   *
   * * [address] - It can either be a [String] or an [InternetAddress].
   * Default: InternetAddress.ANY_IP_V4 (i.e., "0.0.0.0").
   * It will cause Stream server to listen all adapters
   * IP addresses using IPv4.
   *
   * * [port] - the port. Default: 8443.
   * If port has the value 0 an ephemeral port will be chosen by the system.
   * The actual port used can be retrieved using [HttpChannel.port].
   * * [zoned] - whether to start the server within a zone (i.e., `runZoned()`)
   * Default: true.
   */
  Future<HttpChannel> startSecure(SecurityContext context,
      {address, int port: 8443,
      bool v6Only: false, bool requestClientCertificate: false,
      int backlog: 0, bool shared: false, bool zoned: true});
  /** Starts the server to an existing socket.
   *
   * Notice that you can invoke [start], [startSecure] and [startOn] multiple
   * times to handle multiple channels:
   *
   *     new StreamServer()
   *       ..start(port: 80)
   *       ..startSecure(address: "11.22.33.44", port: 443)
   *       ..startOn(fooSocket);
   *
   * To know which channel a request is received, you can access
   * [HttpConnect.channel].
   *
   * Unlike [start], when the channel or the server is closed, the server
   * will just detach itself, but not closing [socket].
   * 
   * * [zoned] - whether to start the server within a zone (i.e., `runZoned()`)
   * Default: true.
   */
  HttpChannel startOn(ServerSocket socket, {bool zoned: true});
  /** Stops the server. It will close all [channels].
   *
   * To close an individual channel, please use [HttpChannel.close] instead.
   */
  Future stop();

  /** Forward the given [connect] to the given [uri].
   *
   * If [request] and/or [response] is ignored, [connect]'s request and/or response is assumed.
   * If [uri] is null, `connect.uri` is assumed, i.e., forwarded to the same handler.
   *
   * After calling this method, the caller shall write the output stream in `then`, since
   * the request handler for the given URI might handle it asynchronously. For example,
   *
   *     await forward(connect, "another");
   *     connect.response.write("<p>More content</p>");
   *     ...
   *
   * * [uri] - the URI to chain. If omitted, it is the same as [connect]'s.
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
   * It also implies before calling [forward], no content shall be output.
   * Otherwise, it will cause exception if the forwarded page updates the HTTP headers.
   *
   * Notice that the whitespaces at the beginning of a RSP file won't be output, so the
   * following is correct:
   *
   *     [:if !isAuthenticated()]
   *       [:forward "/login" /]
   *     [:/if]
   */
  Future forward(HttpConnect connect, String uri, {
    HttpRequest request, HttpResponse response});
  /** Includes the given [uri].
   *
   * If [request] and/or [response] is ignored, [connect]'s request and/or response is assumed.
   * If [uri] is null, `connect.uri` is assumed, i.e., includes the same handler.
   *
   * After calling this method, the caller shall write the output stream in `then`, since
   * the request handler for the given URI might handle it asynchronously. For example,
   *
   *     include(connect, "another");
   *     connect.response.write("<p>More content</p>");
   *     ...
   *
   * * [uri] - the URI to chain. If omitted, it is the same as [connect]'s.
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
   * It also implies before calling [forward], no content shall be output.
   * Otherwise, it will cause exception if the forwarded page updates the HTTP headers.
   */
  Future include(HttpConnect connect, String uri, {
    HttpRequest request, HttpResponse response});

  /** The resource loader used to load the static resources.
   * It is called if the path of a request doesn't match any of the URL
   * mapping given in the constructor.
   */
  ResourceLoader resourceLoader;

  /** The application-specific error handler to listen all uncaught errors
   * that ever happen in this server.
   *
   * If the [connect] argument is null, it means it is a server error,
   * or a uncaught error happening in an asynchronous operation.
   * If not null, it means it is caused by an event handler or an event filter.
   *
   * Notice: all uncaught error will be handled automatically, such as
   * closing up the connection, if any, and log the error message,
   * Thus, you rarely need to register an error handler.
   * 
   * Once [onError] is assigned, the default logging will be disabled,
   * i.e., it is [onError]'s job to log it.
   */
  void onError(void onError(HttpConnect connect, error, stackTrace));

  /** Specifies a callback called when the server is idle, i.e.,
   * not serving any requests ([connectionCount] is 0).
   *
   * It is useful if you'd like to stop the server *gracefully*:
   *
   *     server.onIdle(() => server.stop());
   *
   * In additions, you can do some house cleaning here too.
   *
   * * See also [connectionCount] and [shallCount].
   */
  void onIdle(void onIdle());

  /** The number of active connections.
   * It is also the number of requests in processing.
   * If zero, it means the server is idle.
   *
   * * See also [onIdle] and [shallCount].
   */
  int get connectionCount;
  /** A callback to control whether to increase [connectionCount].
   * If not specified (default), it counts each connection.
   *
   * Note: it also affects when [onIdle] is called.
   */
  void set shallCount(bool shallCount(HttpConnect connect));

  /** Maps the given URI to the given handler.
   *
   * * [uri] - a regular expression used to match the request URI.
   * If you can name a group by prefix with a name, such as `'/dead-link(info:.*)'`.
   * * [handler] - the handler for handling the request, or another URI that this request
   * will be forwarded to.  If the value is a URI and the key has named groups, the URI can
   * refer to the group with `(the_group_name)`.
   * For example: `'/dead-link(info:.*)': '/new-link(info)'`.
   * if [handler] is null, it means removal.
   * * [preceding] - whether to make the mapping preceding any previous mappings.
   * In other words, if true, this mapping will be interpreted first.
   */
  void map(String uri, handler, {bool preceding: false});
  /** Maps the given URI to the given filter.
   *
   * * [uri]: a regular expression used to match the request URI.
   * * [filter]: the filter. If null, it means removal.
   * * [preceding] - whether to make the mapping preceding any previous mappings.
   * In other words, if true, this mapping will be interpreted first.
   */
  void filter(String uri, RequestFilter filter, {bool preceding: false});

  /** The logger for logging information.
   */
  Logger get logger;

  /** Returns a readonly list of channels served by this server.
   * Each time [start], [startSecure] or [startOn] is called, an instance
   * is added to the returned list.
   *
   * To close a particular channel, invoke [HttpChannel.close]. To close all,
   * invoke [stop] to stop the server.
   */
  List<HttpChannel> get channels;
}

/** A generic server error.
 */
class ServerError extends Error {
  final String message;

  ServerError(this.message);

  @override
  String toString() => "ServerError($message)";
}
