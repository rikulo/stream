//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Jan 08, 2013 12:08:05 PM
// Author: tomyeh
part of stream;

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
   * * [futureOnly] - whether every request handler shall return a Future instance.
   * If false (default), a request handler can return null (or nothing) to indicate
   * the request has been served immediately. However, it is also a common error -- forget
   * to return a Future object. To avoid this problem, you can return a Future object
   * in each your handler, and then specify this argument to true to have Stream server
   * to ensure it.
   */
  factory StreamServer({Map<String, dynamic> uriMapping,
      Map errorMapping, Map<String, RequestFilter> filterMapping,
      String homeDir, LoggingConfigurer loggingConfigurer, bool futureOnly: false})
  => new _StreamServer(
      new DefaultRouter(uriMapping: uriMapping,
        errorMapping: errorMapping, filterMapping: filterMapping),
      homeDir, loggingConfigurer, futureOnly);

  /** Constructs a server with the given router.
   * It is used if you'd like to use your own router, rather than the default one.
   */
  factory StreamServer.router(Router router, {String homeDir,
      LoggingConfigurer loggingConfigurer, bool futureOnly: false})
  => new _StreamServer(router, homeDir, loggingConfigurer, futureOnly);

  /** The version.
   */
  String get version;
  /** When the server started. It is null if never started.
   */
  DateTime get startedSince;
  /** The path of the home directory. It is the directory that static resources
   * are loaded from.
   */
  Path get homeDir;
  /** A list of names that will be used to locate the resource if
   * the given path is a directory.
   *
   * Default: `index.html`
   */
  List<String> get indexNames;

  /** The port. Default: 8080.
   */
  int port;
  /** The host. It can either be a [String] or an [InternetAddress].
   *
   * Default: InternetAddress.ANY_IP_V4 (i.e., "0.0.0.0").
   * It will cause Stream server to listen all adapters
   * IP addresses using IPv4.
   */
  var host;

  /** The timeout, in seconds, for sessions of this server.
   * Default: 1200 (unit: seconds)
   */
  int sessionTimeout;

  /** Indicates whether the server is running.
   */
  bool get isRunning;
  /** Starts the server
   */
  Future<StreamServer> start({int backlog: 0});
  /** Starts the server listening for HTTPS request.
   */
  Future<StreamServer> startSecure({String certificateName, bool requestClientCertificate: false,
    int backlog: 0});
  /** Starts the server to an existing the given socket.
   *
   * Notice [host] and [port] are ignored.
   */
  void startOn(ServerSocket socket);
  /** Stops the server.
   */
  void stop();

  /** Forward the given [connect] to the given [uri].
   *
   * If [request] and/or [response] is ignored, [connect]'s request and/or response is assumed.
   * If [uri] is null, `connect.uri` is assumed, i.e., forwarded to the same handler.
   *
   * After calling this method, the caller shall write the output stream in `then`, since
   * the request handler for the given URI might handle it asynchronously. For example,
   *
   *     forward(connect, "another").then((_) {
   *       connect.response.write("<p>More content</p>");
   *       //...
   *     });
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
   *     include(connect, "another").then((_) {
   *       connect.response.write("<p>More content</p>");
   *       //...
   *     });
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

  /** The application-specific error handler to listen all errors that
   * ever happens in this server.
   *
   * If the connect argument is null, it means it is a server error.
   * If not null, it means it is caused by an event handler or filter.
   */
  void onError(void handler(HttpConnect connect, err, [stackTrace]));

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
  void map(String uri, handler, {preceding: false});
  /** Maps the given URI to the given filter.
   *
   * * [uri]: a regular expression used to match the request URI.
   * * [filter]: the filter. If null, it means removal.
   * * [preceding] - whether to make the mapping preceding any previous mappings.
   * In other words, if true, this mapping will be interpreted first.
   */
  void filter(String uri, RequestFilter filter, {preceding: false});

  /** The logger for logging information.
   * The default level is `INFO`.
   */
  Logger get logger;

  /** Returns the information summarizing the number of current connections
   * handled by the server.
   */
  HttpConnectionsInfo get connectionsInfo;
}

/** A generic server error.
 */
class ServerError implements Error {
  final String message;

  ServerError(this.message);
  String toString() => "ServerError($message)";
}
