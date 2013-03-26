//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Mon, Mar 25, 2013 10:38:58 AM
// Author: tomyeh
part of stream_plugin;

/**
 * Router for mapping URI to renderers.
 */
abstract class Router {
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
 * The default implementation of [Rounter]
 */
class DefaultRouter implements Router {
  final List<_UriMapping> _uriMapping = [], _filterMapping = [];
  final Map<int, dynamic> _codeMapping = new HashMap(); //mapping of status code to URI/Function
  final List<_ErrMapping> _errMapping = []; //exception to URI/Function

  DefaultRouter(Map<String, dynamic> uriMapping,
      Map errorMapping, Map<String, RequestFilter> filterMapping) {
    if (uriMapping != null)
      for (final uri in uriMapping.keys) {
        _chkUri(uri, "URI");

        final handler = uriMapping[uri];
        if (handler is! Function && handler is! String)
          throw new ServerError("URI mapping: function (renderer) or string (URI) is required for $uri");
        _uriMapping.add(new _UriMapping(uri, handler));
      }

    //default mapping
    _uriMapping.add(new _UriMapping("/.*[.]rsp(|[.][^/]*)", _f404));
      //prevent .rsp and .rsp.* from access

    if (filterMapping != null)
      for (final uri in filterMapping.keys) {
        _chkUri(uri, "Filter");

        final handler = filterMapping[uri];
        if (handler is! Function)
          throw new ServerError("Filter mapping: function (filter) is required for $uri");
        _filterMapping.add(new _UriMapping(uri, handler));
      }

    if (errorMapping != null)
      for (var code in errorMapping.keys) {
        final handler = errorMapping[code];
        if (handler is String) {
          _chkUri(handler, "Error");
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

  @override
  getHandler(HttpConnect connect, String uri) {
    //TODO: cache the matched result for better performance
    for (final mp in _uriMapping)
      if (mp.match(connect, uri)) {
        var handler = mp.handler;
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

///check if the given URI is correct
void _chkUri(String uri, String msg) {
  if (uri.isEmpty || "/.[(".indexOf(uri[0]) < 0)
    throw new ServerError("$msg mapping: URI must start with '/', '.', '[' or '('; not '$uri'");
      //ensure it is absolute or starts with regex wildcard
}

class _UriMapping {
  RegExp _ptn;
  Map<int, String> _groups;
  ///It could be a function, a string or a list of (string or _Var).
  var handler;

  _UriMapping(String uri, handler) {
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
