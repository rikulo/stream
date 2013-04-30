//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Mon, Mar 25, 2013 10:38:58 AM
// Author: tomyeh
part of stream_plugin;

/**
 * Router for mapping URI to renderers.
 */
abstract class Router {
  /** Maps the given URI to the given handler.
   *
   * The interpretation of [uri] and [handler] is really up to the
   * implementation of [Router].
   *
   * * [handler] - if handler is null, it means removal.
   * * [preceding] - whether to make the mapping preceding any previous mappings.
   * In other words, if true, this mapping will be interpreted first.
   */
  void map(String uri, handler, {preceding: false});
  /** Maps the given URI to the given filter.
   *
   * The interpretation of [uri] is really up to the implementation of [Router].
   *
   * * [filter] - if filter is null, it means removal.
   * * [preceding] - whether to make the mapping preceding any previous mappings.
   * In other words, if true, this mapping will be interpreted first.
   */
  void filter(String uri, RequestFilter filter, {preceding: false});

  /** Retrieves the first matched request handler ([RequestHandler]) or
   * forwarded URI ([String]) for the given URI.
   */
  getHandler(HttpConnect connect, String uri);
  /** Returns the index of the next matched request filter for the given URI
   * and starting at the given index.
   *
   * It returns null if not found.
   */
  int getFilterIndex(HttpConnect connect, String uri, int iFilter);
  ///Returns the filter at the given index.
  RequestFilter getFilterAt(int iFilter);
  ///Returns the error handler ([RequestHandler]) or a URI ([String])
  ///based on the given error (i.e., the exception)
  getErrorHandler(error);
  ///Returns the error handler ([RequestHandler]) or a URI ([String])
  ///based on the error code (i.e., the HTTP status code)
  getErrorHandlerByCode(int code);
}

/**
 * The default implementation of [Router].
 */
class DefaultRouter implements Router {
  final List<_UriMapping> _uriMapping = [], _filterMapping = [];
  final Map<int, dynamic> _codeMapping = new HashMap(); //mapping of status code to URI/Function
  final List<_ErrMapping> _errMapping = []; //exception to URI/Function

  final Map<String, dynamic> _uriCache = new LinkedHashMap();
  int _cacheSize;

  static final _NOT_FOUND = new Object();

  /** The constructor.
   *
   * * [cacheSize] - the size of the cache for speeding up URI matching.
   */
  DefaultRouter(Map<String, dynamic> uriMapping, Map errorMapping,
			Map<String, RequestFilter> filterMapping, {int cacheSize:1000}) {
    _cacheSize = cacheSize;

    if (uriMapping != null)
      for (final uri in uriMapping.keys)
        map(uri, uriMapping[uri]);

    //default mapping
    _uriMapping.add(new _UriMapping("/.*[.]rsp(|[.][^/]*)", _f404));
      //prevent .rsp and .rsp.* from access

    if (filterMapping != null)
      for (final uri in filterMapping.keys)
        filter(uri, filterMapping[uri]);

    if (errorMapping != null)
      for (var code in errorMapping.keys) {
        final handler = errorMapping[code];
        if (handler is String) {
          String uri = handler;
          if (!uri.startsWith('/'))
            throw new ServerError("URI must start with '/'; not '$uri'");
        } else if (handler is! Function) {
          throw new ServerError("Error mapping: function (renderer) or string (URI) is required for $code");
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
  void map(String uri, handler, {preceding: false}) {
    if (handler != null && handler is! Function && handler is! String)
      throw new ServerError("URI mapping: function (renderer) or string (URI) is required for $uri");

    _map(_uriMapping, uri, handler, preceding);
    _uriCache.clear();
  }
  /** Maps the given URI to the given filter.
   *
   * * [uri]: a regular expression used to match the request URI.
   * * [filter]: the filter. If it is null, it means removal.
   * * [preceding] - whether to make the mapping preceding any previous mappings.
   * In other words, if true, this mapping will be interpreted first.
   */
  void filter(String uri, RequestFilter filter, {preceding: false}) {
    if (filter is! Function)
      throw new ServerError("Filter mapping: function (filter) is required for $uri");
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

  @override
  getHandler(HttpConnect connect, String uri) {
    var handler = _uriCache[uri];
    if (handler == null) {
      _UriMapping mp;
      for (mp in _uriMapping)
        if (mp.match(connect, uri)) {
          handler = mp.handler;
          break;
        }

      //store to cache
      _uriCache[uri] = handler == null ? _NOT_FOUND:
        mp.hasGroup() ? mp: handler; //store _UriMapping if mp.hasGroup()
      if (_uriCache.length > _cacheSize)
        _uriCache.remove(_uriCache.keys.first);
    } else if (identical(handler, _NOT_FOUND)) {
      return;
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
  int getFilterIndex(HttpConnect connect, String uri, int iFilter) {
    for (; iFilter < _filterMapping.length; ++iFilter)
      if (_filterMapping[iFilter].match(connect, uri))
        return iFilter;
  }
  @override
  RequestFilter getFilterAt(int iFilter) {
    return _filterMapping[iFilter].handler;
  }
  @override
  getErrorHandler(error) {
    if (!_errMapping.isEmpty) {
      final caughtClass = reflect(error).type;
      for (final mapping in _errMapping)
        if (ClassUtil.isAssignableFrom(mapping.error, caughtClass)) //found
          return mapping.handler;
    }
  }
  @override
  getErrorHandlerByCode(int code) => _codeMapping[code];
}

///Renderer for 404
final _f404 = (_) {throw new Http404();};

class _UriMapping {
  final String uri;
  RegExp _ptn;
  Map<int, String> _groups;
  ///It could be a function, a string or a list of (string or _Var).
  var handler;
  ///The method to match with
  String method;

  _UriMapping(this.uri, handler) {
    _parseHandler(handler);
    _parseUri(uri);
  }
  void _parseHandler(handler) {
    if (handler is String) {
      final String val = handler;
      List segs = [];
      int k = 0, len = val.length;
      for (int i = 0; i < len; ++i) {
        switch (val[i]) {
          case '\\':
            if (i + 1 < len)
              ++i; //skip next
            break;
          case '(':
            if (i + 1 < len) {
              if (k < i)
                segs.add(val.substring(k, i));
              for (k = ++i;; ++k) {
                if (k >= len)
                  throw new ServerError("Expect ')': $val");
                if (val[k] == ')') {
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
    this.handler = handler;
  }
  void _parseUri(String uri) {
    //handle get:xxx, post:xxx
    for (int i = 0, len = uri.length; i < len; ++i) {
      final cc = uri[i];
      if (cc == ':') {
        if (i > 0) {
          method = uri.substring(0, i).toUpperCase();
          uri = uri.substring(i + 1);
        }
        break; //done
      } else if (!StringUtil.isChar(cc, upper:true, lower:true)) {
        break;
      }
    }

    if (uri.isEmpty || "/.[(".indexOf(uri[0]) < 0)
      throw new ServerError("URI pattern must start with '/', '.', '[' or '('; not '$uri'");
      //ensure it is absolute or starts with regex wildcard

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
  bool hasGroup() => _groups != null;
  bool match(HttpConnect connect, String uri) {
    if (method != null && method != connect.request.method)
      return false; //not matched

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

class _Var {
  final String name;
  _Var(this.name);

  String toString() => name;
}

class _ErrMapping {
  final ClassMirror error;
  final handler;
  _ErrMapping(this.error, this.handler);
}
