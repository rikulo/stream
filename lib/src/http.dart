//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Jan 08, 2013 12:04:43 PM
// Author: tomyeh
part of stream;

/** The session.
 *
 * Unlike `HttpSession`, [data] is not writable. You shall use [attributes]
 * instead.
 */
class StreamSession implements HttpSession {
  final HttpSession _origin;

  StreamSession(HttpSession this._origin) {
    _origin.data = this;
  }

  /** A map of application-specific attributes.
   */
  final Map<String, dynamic> attributes = {};

  @override
  String get id => _origin.id;

  //@override
  /// It is the same as [attributes].
  dynamic get data => attributes;
  //@override
  /// Unsupported. Please use [attributes] instead.
  void set data(dynamic data) {
    throw new UnsupportedError("Reserved for internal use; use attributes instead.");
  }

  //@override
  void destroy() => _origin.destroy();
  @override
  void set onTimeout(void callback()) {
    _origin.onTimeout = callback;
  }
}

/** The request.
 */
class StreamRequest extends HttpRequestWrapper {
  StreamRequest(HttpRequest origin): super(origin);

  /** A map of application-specific models.
   * It is used to pass models from the action (aka., controller) to the view.
   */
  final Map<String, dynamic> models = {};

  /** A map of application-specific attributes.
   */
  final Map<String, dynamic> attributes = {};

  //@override
  StreamSession session([init(HttpSession session)])
  => origin.session(init == null ? _initSess:
      (HttpSession session) => init(_initSess(session)))
    .data; //origin.data is StreamSession
}
_initSess(HttpSession session) => new StreamSession(session);

/** The response.
 */
class StreamResponse extends HttpResponseWrapper {
  StreamResponse(HttpResponse origin): super(origin);
}
