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
  /// * [handler] - if handler is null, it means removal.
  /// * [preceding] - whether to make the mapping preceding any previous mappings.
  /// In other words, if true, this mapping will be interpreted first.
  void map(String uri, handler, {bool preceding = false});

  /// Maps the given URI to the given filter.
  ///
  /// The interpretation of [uri] is really up to the implementation of [Router].
  ///
  /// * [filter] - if filter is null, it means removal.
  /// * [preceding] - whether to make the mapping preceding any previous mappings.
  /// In other words, if true, this mapping will be interpreted first.
  void filter(String uri, RequestFilter filter, {bool preceding = false});

  /// Retrieves the first matched request handler ([RequestHandler]) or
  /// forwarded URI ([String]) for the given URI.
  getHandler(HttpConnect connect, String uri);

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
  getErrorHandler(error);
}

/**
 * The default implementation of [Router].
 */
class DefaultRouter implements Router {
  final _uriMapping = <_UriMapping>[], _filterMapping = <_UriMapping>[];
  final _errorMapping = new HashMap<int, dynamic>(); //mapping of status code to URI/Function

  final _uriCache = new _UriCache();
  final int _cacheSize;

  static final _notFound = new Object();

  /** The constructor.
   *
   * * [cacheSize] - the size of the cache for speeding up URI matching.
   * * [protectRSP] - protects RSP files from accessing at the client.
   * You can specify it to false if you don't put RSP files with client
   * resource files.
   */
  DefaultRouter({Map<String, dynamic>? uriMapping,
      Map<int, dynamic>? errorMapping,
      Map<String, RequestFilter>? filterMapping,
      int cacheSize = 1000, bool protectRSP = true}): _cacheSize = cacheSize {

    if (uriMapping != null)
      uriMapping.forEach(map);

    //default mapping
    if (protectRSP)
      _uriMapping.add(new _UriMapping("/.*[.]rsp(|[.][^/]*)", _f404));
        //prevent .rsp and .rsp.* from access

    if (filterMapping != null)
      filterMapping.forEach(filter);

    if (errorMapping != null)
      errorMapping.forEach((code, handler) {
        final handler = errorMapping[code];
        if (handler is String) {
          String uri = handler;
          if (!uri.startsWith('/'))
            throw new ServerError("URI must start with '/'; not '$uri'");
        } else if (handler is! Function) {
          throw new ServerError("Error mapping: function (renderer) or string (URI) is required for $code");
        }

        _errorMapping[code] = handler;
      });
  }

  /** Maps the given URI to the given handler.
   *
   * * [uri] - a regular expression used to match the request URI.
   * If you can name a group by prefix with a name, such as `'/dead-link(info:.*)'`.
   * * [handler] - the handler for handling the request, or another URI that this request
   * will be forwarded to. If the value is a URI and the key has named groups, the URI can
   * refer to the group with `(the_group_name)`.
   * For example: `'/dead-link(info:.*)': '/new-link(info)'`.
   * If it is null, it means removal.
   * * [preceding] - whether to make the mapping preceding any previous mappings.
   * In other words, if true, this mapping will be interpreted first.
   */
  @override
  void map(String uri, handler, {preceding = false}) {
    if (handler != null && handler is! Function && handler is! String)
      throw new ServerError("URI mapping: function (renderer) or string (URI) is required for $uri");

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
  void filter(String uri, RequestFilter filter, {bool preceding = false}) {
    _map(_filterMapping, uri, filter, preceding);
  }
  static void _map(List<_UriMapping> mapping, String uri, handler, bool preceding) {
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
      final m = new _UriMapping(uri, handler);
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
  getHandler(HttpConnect connect, String uri) {
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
          mp!.hasGroup() ? mp: handler; //store _UriMapping if mp.hasGroup()
        if (cache.length > _cacheSize)
          cache.remove(cache.keys.first);
      }
    } else if (identical(handler, _notFound)) {
      return null;
    } else if (handler is _UriMapping) { //hasGroup
      handler.match(connect, uri); //prepare connect.dataset
      handler = handler.handler;
    }

    if (handler is List) {
      final sb = new StringBuffer();
      for (var seg in handler) {
        if (seg is _Var) {
          seg = connect.dataset[seg.name];
          if (seg == null)
            continue; //skip
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
  getErrorHandler(error) => _errorMapping[error];
}

///Renderer for 404
final RequestHandler _f404 = (HttpConnect _) {throw new Http404();};

typedef Future _WSHandler(WebSocket socket);

///Returns a function that can *upgrade* HttpConnect to WebSocket
Function _upgradeWS(Future handler(WebSocket socket))
=> (HttpConnect connect)
  => WebSocketTransformer.upgrade(connect.request).then(handler);

class _UriMapping {
  final String uri;
  final RegExp _ptn;
  final Map<int, String>? _groups;
  ///It could be a function, a string or a list of (string or _Var).
  final handler;
  ///The method to match with. (It is in upper case)
  final String? method;

  _UriMapping._(this.uri, this.handler, this.method, this._groups, this._ptn);

  factory _UriMapping(String uri, final rawhandler) {
    //1. Parse handler
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
                  throw new ServerError("Expect ')': $val");
                if (val.codeUnitAt(k) == $rparen) {
                  segs.add(new _Var(val.substring(i, k)));
                  i = k++;
                  break;
                }
              }
            }
            break;
        }
      }

      if (!segs.isEmpty) {
        if (k < len)
          segs.add(val.substring(k));
        handler = segs;
      }
    }

    //2. parse URI
    //handle get:xxx, post:xxx, ws:xxz
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
      throw new ServerError("URI pattern must start with '/', '.', '[' or '('; not '$uri'");
      //ensure it is absolute or starts with regex wildcard

    uri = "^$uri\$"; //match the whole URI
    final groups = new HashMap<int, String>();

    //parse grouping: ([a-zA-Z_-]+:regex)
    final sb = new StringBuffer();
    bool bracket = false;
    l_top:
    for (int i = 0, grpId = 0, len = uri.length; i < len; ++i) {
      switch (uri.codeUnitAt(i)) {
        case $backslash:
          if (i + 1 < len) {
            sb.write('\\');
            ++i; //skip next
          }
          break;
        case $lbracket:
          bracket = true;
          break;
        case $rbracket:
          bracket = false;
          break;
        case $lparen:
          if (bracket)
            break;

          sb.write('(');

          //parse the name of the group, if any
          String? nm;
          final nmsb = new StringBuffer();
          int j = i;
          for (;;) {
            if (++j >= len) {
              sb.write(nmsb);
              break l_top;
            }

            final cc = uri.codeUnitAt(j);
            if (StringUtil.isCharCode(cc, lower:true, upper:true, digit: true)
            || cc == $underscore || cc == $dot) {
              nmsb.writeCharCode(cc);
            } else {
              if (cc == $colon && !nmsb.isEmpty) {
                nm = nmsb.toString();
              } else {
                sb.write(nmsb);
                --j;
              }
              break;
            }
          } //for(;;)
          i = j;

          if (nm != null)
            groups[grpId] = nm;
          ++grpId;
          continue;
      }
      sb.writeCharCode(uri.codeUnitAt(i));
    }

    if (method == "WS") { //handle specially
      if (rawhandler is! Function)
        throw new ServerError(
          "'ws:' must be mapped to a function handler, not $rawhandler");
      handler = _upgradeWS(rawhandler as _WSHandler);
      method = null;
    }

    final hasGroup = groups.isNotEmpty;
    return _UriMapping._(uri, handler, method, hasGroup ? groups: null,
        new RegExp(hasGroup ? sb.toString(): uri));
  }

  bool hasGroup() => _groups != null;

  bool match(HttpConnect connect, String uri) {
    if (method != null && method != connect.request.method)
      return false; //not matched

    final m = _ptn.firstMatch(uri);
    if (m != null) {
      final groups = _groups;
      if (groups != null) {
        final count = m.groupCount;
        groups.forEach((key, value) {
          if (key < count) //unlikely but be safe
            connect.dataset[value] = m.group(key + 1); //group() starts from 1 (not 0)
        });
      }
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
      cache = _cache = new LinkedHashMap<String, dynamic>();

      _multimethod = false;
      for (final m in mappings)
        if (m.method != null) {
          _multimethod = true;
          break;
        }
    }

    return _multimethod == true ? 
      cache.putIfAbsent(connect.request.method,
          () => new LinkedHashMap<String, dynamic>()) as Map<String, dynamic>:
      cache;
  }
}
