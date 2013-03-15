//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Jan 08, 2013 12:08:05 PM
// Author: tomyeh
part of stream;

/** The filter. It is used with the `filterMapping` parameter of [StreamServer].
 *
 * * [chain] - the callback to *resume* the request handling. If there is another filter,
 * it will be invoked when you call back [chain]. If you'd like to skip the handling (e.g., redirect to another page),
 * you don't have to call back [chain].
 *
 * Before calling back [chain], you can proxy the request and/or response, such as writing the
 * the response to a string buffer.
 */
typedef void Filter(HttpConnect connect, void chain(HttpConnect conn));

/** Converts the given value to a string by calling its `toString`.
 * If the given value is null, an empty string is returned.
 */
String stringize(v) => v != null ? v.toString(): "";

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
   * * [uriMapping] - a map of URI mappings, `<String uri, Function handler>`.  The URI is
   * a regular exception used to match the request URI.
   * * [filterMapping] - a map of filter mapping, `<String uri, Function filter>`. The signature
   * of a filter is `void foo(HttpConnect connect, void chain(HttpConnect conn))`.
   * * [errorMapping] - a map of error mapping. The key can be a number, an instance of
   * exception, a string representing a number, or a string representing the exception class.
   * The value can be an URI or a renderer function. The number is used to represent a status code,
   * such as 404 and 500. The exception is used for matching the caught exception.
   * Notice that, if you specify the name of the exception to handle,
   * it must include the library name and the class name, such as `"stream.ServerError"`.
   */
  factory StreamServer({Map<String, Function> uriMapping,
    Map errorMapping, Map<String, Filter> filterMapping,
    String homeDir, LoggingConfigurer loggingConfigurer})
  => new _StreamServer(uriMapping, errorMapping, filterMapping, homeDir, loggingConfigurer);

  /** The version.
   */
  String get version;
  /** The path of the home directory.
   */
  Path get homeDir;
  /** A list of names that will be used to locate the resource if
   * the given path is a directory.
   *
   * Default: `[index.html]`
   */
  List<String> get indexNames;

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
   * * The request handler that invokes [forward] shall not call `connect.close` (it is the job
   * of the callee -- the forwarded request handler).
   */
  void forward(HttpConnect connect, String uri, {Handler success,
    HttpRequest request, HttpResponse response});
  /** Includes the given [uri].
   * If you'd like to include a request handler (i.e., a function), use [connectForInclusion]
   * instead.
   *
   * If [request] and/or [response] is ignored, [connect]'s request and/or response is assumed.
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
   * * The request handler that invokes [forward] shall not call `connect.close` (it is the job
   * of the callee -- the included request handler).
   */
  void include(HttpConnect connect, String uri, {Handler success,
    HttpRequest request, HttpResponse response});
  /** Gets the HTTP connect for inclusion.
   * If you'd like to include from URI, use [include] instead.
   * This method is used for including a request handler. For example
   *
   *     fooHandler(connectForInclusion(connect, success: () {continueToDo();}));
   */
  HttpConnect connectForInclusion(HttpConnect connect, {String uri, Handler success,
    HttpRequest request, HttpResponse response});

  /** The resource loader used to load the static resources.
   * It is called if the path of a request doesn't match any of the URL
   * mapping given in the constructor.
   */
  ResourceLoader resourceLoader;

  /** The application-specific error handler. Default: null.
   */
  void onError(ConnectErrorHandler handler);
  /** The default content handler. It is invoked after the handler assigned
   * to [onError], if any.
   */
  ConnectErrorHandler get defaultErrorHandler;

  /** The logger for logging information.
   * The default level is `INFO`.
   */
  Logger get logger;
}

/** A generic server error.
 */
class ServerError implements Error {
  final String message;

  ServerError(this.message);
  String toString() => "ServerError($message)";
}
