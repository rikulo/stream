//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Mon, Mar 25, 2013 10:38:58 AM
// Author: tomyeh
part of stream_plugin;

/// Router for mapping URI to renderers.
abstract class Router {
  /// Maps the given URI to the given handler.
  ///
  /// The interpretation of [uri] and [handler] is really up to the
  /// implementation of [Router].
  ///
  /// > Please refer to [DefaultRouter.map] for how it handles the regular
  /// expressions.
  ///
  /// * [uri] - a pattern, either [String] or [RegExp].
  /// * [handler] - if handler is null, it means removal.
  /// * [preceding] - whether to make the mapping preceding any previous mappings.
  /// In other words, if true, this mapping will be interpreted first.
  void map(Pattern uri, Object? handler, {bool preceding = false});

  /// Maps the given URI to the given filter.
  ///
  /// The interpretation of [uri] is really up to the implementation of [Router].
  ///
  /// * [uri] - a pattern, either [String] or [RegExp].
  /// * [filter] - if filter is null, it means removal.
  /// * [preceding] - whether to make the mapping preceding any previous mappings.
  /// In other words, if true, this mapping will be interpreted first.
  void filter(Pattern uri, RequestFilter filter, {bool preceding = false});

  /// Retrieves the first matched request handler ([RequestHandler]) or
  /// forwarded URI ([String]) for the given URI.
  Object? getHandler(HttpConnect connect, String uri);

  /// Returns the index of the next matched request filter for the given URI
  /// and starting at the given index.
  ///
  /// It returns null if not found.
  int? getFilterIndex(HttpConnect connect, String uri, int iFilter);

  /// Returns the filter at the given index.
  RequestFilter getFilterAt(int iFilter);

  /// Returns the error handler ([RequestHandler]) or a URI ([String])
  /// based on the error thrown by a request handler.
  /// 
  /// You can override this method to detect the type of the error
  /// and then return a handler for it. The handler can retrieve
  /// the error via [connect.errorDetail].
  Object? getErrorHandler(Object? error);
}

/**
 * The default implementation of [Router].
 */
class DefaultRouter implements Router {
  final _uriMapping = <_UriMapping>[],
    _filterMapping = <_UriMapping>[],
    _errorMapping = HashMap<int, dynamic>(), //mapping of status code to URI/Function
    _uriCache = _UriCache();
  final int _cacheSize;

  static final _notFound = Object();

  /// The constructor.
  ///
  /// * [uriMapping] - The key can be a String or RegExp instance.
  /// If String, an instance of `RegExp('^$pattern\$')` will be generated
  /// and used. Refer to [map] for details.
  /// * [cacheSize] - the size of the cache for speeding up URI matching.
  /// * [protectRSP] - protects RSP files from accessing at the client.
  /// You can specify it to false if you don't put RSP files with client
  /// resource files.
  DefaultRouter({Map<Pattern, dynamic>? uriMapping,
      Map<int, dynamic>? errorMapping,
      Map<String, RequestFilter>? filterMapping,
      int cacheSize = 1000, bool protectRSP = true}):
      _cacheSize = cacheSize {

    if (uriMapping != null)
      uriMapping.forEach(map);

    //default mapping
    if (protectRSP)
      _uriMapping.add(_UriMapping("/.*[.]rsp(|[.][^/]*)", _f404));
        //prevent .rsp and .rsp.* from access

    if (filterMapping != null)
      filterMapping.forEach(filter);

    if (errorMapping != null)
      errorMapping.forEach((code, handler) {
        final handler = errorMapping[code];
        if (handler is String) {
          if (!handler.startsWith('/'))
            throw ServerError("URI must start with '/'; not '$handler'");
        } else if (handler is! Function) {
          throw ServerError("Error mapping: function (renderer) or string (URI) is required for $code");
        }

        _errorMapping[code] = handler;
      });
  }

  /// Maps the given URI to the given handler.
  ///
  /// * [uri] - a pattern, either String or RegExp.
  /// If String, an instance of `RegExp('^$pattern\$')` will be generated
  /// and used for matching the requested URI.
  ///
  /// You can also specify the HTTP method in the pattern,
  /// such as GET, POST, and PUT.
  /// For example, `'get:/foo'` accepts only the GET method.
  ///
  /// Note: you can specify WebSocket by prefixing with `ws:`,
  /// e.g., `ws:/mine`.
  ///
  /// You can use the named capturing group, see [handler] for details.
  ///
  /// * [handler] - the handler for handling the request,
  /// or another URI that this request will be forwarded to.
  ///
  /// If the handler is a string, you can refer the named capturing
  /// group with `(the_group_name)`.
  /// For example: `'/dead-link/(?<info>.*)': '/new-link/(info)'`
  /// will forward `/dead-link/whatevr` to `/new-link/whatever.
  /// 
  /// If you'd like to redirect, you can do:
  /// 
  ///     '/dead-link/(?<info>.*)': (connect) {
  ///       connect.redirect("/new-link/${DefaultRouter.getNamedGroup(connect, 'info')");
  ///     }
  /// 
  /// > Note: [getNamedGroup] is the util you can use in your handler to
  /// > retrieve the named capturing group.
  ///
  /// * [preceding] - whether to make the mapping preceding any previous mappings.
  /// In other words, if true, this mapping will be interpreted first.
  @override
  void map(Pattern uri, Object? handler, {preceding = false}) {
    if (handler != null && handler is! Function && handler is! String)
      throw ServerError("URI mapping: function (renderer) or string (URI) is required for $uri");

    _map(_uriMapping, uri, handler, preceding);
    _uriCache.reset();
  }

  /** Maps the given URI to the given filter.
   *
   * * [uri]: a regular expression used to match the request URI.
   * * [filter]: the filter. If it is null, it means removal.
   * * [preceding] - whether to make the mapping preceding any previous mappings.
   * In other words, if true, this mapping will be interpreted first.
   */
  @override
  void filter(Pattern uri, RequestFilter filter, {bool preceding = false}) {
    _map(_filterMapping, uri, filter, preceding);
  }
  static void _map(List<_UriMapping> mapping, Pattern uri, Object? handler, bool preceding) {
    if (handler == null) { //removal
      if (preceding) {
        for (int i = 0, len = mapping.length; i < len; ++i)
          if (mapping[i].uri == uri) {
            mapping.removeAt(i);
            break; //done
          }
      } else {
        for (int i = mapping.length; --i >= 0;)
          if (mapping[i].uri == uri) {
            mapping.removeAt(i);
            break; //done
          }
      }
    } else { //add
      final m = _UriMapping(uri, handler);
      if (preceding)
        mapping.insert(0, m);
      else
        mapping.add(m);
    }
  }

  /** Retursn whether the mapping of the given [uri] shall be cached.
   * Default: it always return true.
   */
  bool shallCache(HttpConnect connect, String uri) => true;

  @override
  Object? getHandler(HttpConnect connect, String uri) {
    //check cache first before shallCache => better performance
    //reason: shallCache is likely to return true (after regex)
    final cache = _uriCache.getCache(connect, _uriMapping);
    var handler = cache[uri];

    if (handler == null) {
      _UriMapping? mp;
      for (mp in _uriMapping)
        if (mp.match(connect, uri)) {
          handler = mp.handler;
          break;
        }

      //store to cache
      if (shallCache(connect, uri)) {
        cache[uri] = handler == null ? _notFound:
            mp!.hasNamedGroup ? mp: handler;
            //store _UriMapping if containing named group, so `mp.match()`
            //will be called when matched, see 6th line below
        if (cache.length > _cacheSize)
          cache.remove(cache.keys.first);
      }
    } else if (identical(handler, _notFound)) {
      return null;
    } else if (handler is _UriMapping) { //hasGroup
      handler.match(connect, uri);
        //prepare for [getNamedGroup], since [_setUriMatch]'ll be called
      handler = handler.handler;
    }

    if (handler is List) {
      final sb = StringBuffer();
      for (var seg in handler) {
        if (seg is _Var) {
          seg = getNamedGroup(connect, seg.name);
          if (seg == null) continue; //skip
        }
        sb.write(seg);
      }
      return sb.toString();
    }
    return handler;
  }

  @override
  int? getFilterIndex(HttpConnect connect, String uri, int iFilter) {
    for (; iFilter < _filterMapping.length; ++iFilter)
      if (_filterMapping[iFilter].match(connect, uri))
        return iFilter;
  }

  @override
  RequestFilter getFilterAt(int iFilter)
  => _filterMapping[iFilter].handler as RequestFilter;

  @override
  Object? getErrorHandler(Object? error) => _errorMapping[error];

  /// Retrieves the named capturing group of the given [name],
  /// specified in [map]'s `uri`, or null if not found.
  static String? getNamedGroup(HttpConnect connect, String name) {
    try {
      return (connect.dataset[_attrUriMatch] as RegExpMatch?)?.namedGroup(name);
    } catch (_) { //ignore it
    }
  }
  static void _setUriMatch(HttpConnect connect, Match m) {
    connect.dataset[_attrUriMatch] = m;
  }
  static const _attrUriMatch = '-stream.u.mth-';
}

///Renderer for 404
final RequestHandler _f404 = (HttpConnect _) {throw Http404();};

typedef Future _WSHandler(WebSocket socket);

///Returns a function that can *upgrade* HttpConnect to WebSocket
Function _upgradeWS(Future handler(WebSocket socket))
=> (HttpConnect connect)
  => WebSocketTransformer.upgrade(connect.request).then(handler);

class _UriMapping {
  final String uri;
  final RegExp _reUri;
  ///It could be a function, a string or a list of (string or _Var).
  /// It is a list if it contains the named group.
  final handler;
  ///The method to match with. (It is in upper case)
  final String? method;
  ///The uri pattern likely contains name group
  final bool hasNamedGroup;

  _UriMapping._(this.uri, this._reUri, this.handler, [this.method])
  : hasNamedGroup = _reHasNameGroup.hasMatch(uri);

  static final _reHasNameGroup = RegExp(r'\(\?<[^>=!][^>]*>.*\)');
    //NOTE: it needs not be accurate, since [hasNamedGroup] is used
    //for skipping the invocation of [match] if possible
    //AVOID lookbehind: `(?<=)` or `(?<!)`

  factory _UriMapping(Pattern pattern, final rawhandler) {
    //1. Parse handler: split String into List for named capturing group
    //For example: `/new-link/(group1)`
    var handler = rawhandler;
    if (rawhandler is String) {
      final val = rawhandler;
      final segs = [];
      int k = 0, len = val.length;
      for (int i = 0; i < len; ++i) {
        switch (val.codeUnitAt(i)) {
          case $backslash:
            if (i + 1 < len)
              ++i; //skip next
            break;
          case $lparen:
            if (i + 1 < len) {
              if (k < i)
                segs.add(val.substring(k, i));
              for (k = ++i;; ++k) {
                if (k >= len)
                  throw ServerError("Expect ')': $val");
                if (val.codeUnitAt(k) == $rparen) {
                  segs.add(_Var(val.substring(i, k)));
                  i = k++;
                  break;
                }
              }
            }
            break;
        }
      }

      if (segs.isNotEmpty) {
        if (k < len)
          segs.add(val.substring(k));
        handler = segs;
      }
    }

    //2a. no need to handle if [RegExp]
    if (pattern is RegExp)
      return _UriMapping._(pattern.pattern, pattern, handler);

    //2b. parse pattern: get:xxx, post:xxx, ws:xxz
    var uri = pattern.toString(); //safer
    String? method;
    for (int i = 0, len = uri.length; i < len; ++i) {
      final cc = uri.codeUnitAt(i);
      if (cc == $colon) {
        if (i > 0) {
          method = uri.substring(0, i).toUpperCase();
          uri = uri.substring(i + 1);
        }
        break; //done
      } else if (!StringUtil.isCharCode(cc, upper:true, lower:true)) {
        break;
      }
    }

    int cc;
    if (uri.isEmpty || ((cc = uri.codeUnitAt(0)) != $slash
        && cc != $dot && cc != $lbracket && cc != $lparen))
      throw ServerError("URI pattern must start with '/', '.', '[' or '('; not '$uri'");
      //ensure it is absolute or starts with regex wildcard

    if (_reObsoleteNamedGroup.hasMatch(uri))
      throw ServerError("Use named capturing groups instead: $uri");

    if (method == "WS") { //handle specially
      if (rawhandler is! Function)
        throw ServerError(
          "'ws:' must be mapped to a function handler, not $rawhandler");
      handler = _upgradeWS(rawhandler as _WSHandler);
      method = null;
    }

    return _UriMapping._(uri, RegExp("^$uri\$"), handler, method);
      //NOTE: we match the whole URI
  }
  static final _reObsoleteNamedGroup = RegExp(r'(?<!\\)\(\w+:.*\)');

  bool match(HttpConnect connect, String uri) {
    if (method != null && method != connect.request.method)
      return false; //not matched

    final m = _reUri.firstMatch(uri);
    if (m != null) {
      DefaultRouter._setUriMatch(connect, m);
      return true;
    }
    return false;
  }
}

class _Var {
  final String name;
  _Var(this.name);

  @override
  String toString() => name;
}

class _UriCache {
  ///If _multimethod is false => <String uri, handler>
  ///If _multimethod is true => <String method, <String uri, handler>>
  Map<String, dynamic>? _cache;
  bool? _multimethod;

  void reset() {
    _multimethod = null;
    _cache = null;
  }

  Map<String, dynamic> getCache(HttpConnect connect, List<_UriMapping> mappings) {
    var cache = _cache;
    if (cache == null) { //not initialized yet
      cache = _cache = LinkedHashMap<String, dynamic>();

      _multimethod = false;
      for (final m in mappings)
        if (m.method != null) {
          _multimethod = true;
          break;
        }
    }

    return _multimethod == true ? 
      cache.putIfAbsent(connect.request.method,
          () => LinkedHashMap<String, dynamic>()) as Map<String, dynamic>:
      cache;
  }
}
