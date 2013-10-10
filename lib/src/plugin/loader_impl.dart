//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Oct 09, 2013 11:10:02 AM
// Author: tomyeh
part of stream_plugin;

//--- Cache and File Loading ---//
//--- ---//

class _CacheEntry {
  final List<int> content;
  final int filesize;
  final DateTime lastModified;

  _CacheEntry(this.content, this.lastModified, this.filesize);
}

class _FileCache implements FileCache {
  final FileLoader _loader;
  final Map<String, _CacheEntry> _cache = new LinkedHashMap();
  int _cacheSize = 0;

  _FileCache(this._loader);

  @override
  String getETag(DateTime lastModified, int filesize)
  => _loader.getETag(lastModified, filesize);
  @override
  Duration getExpires(File file)
  => _loader.getExpires(file);

  @override
  bool shallCache(File file, int filesize)
  => _loader.shallCache(file, filesize);
  @override
  List<int> getContent(File file, DateTime lastModified) {
    final String path = file.path;
    final _CacheEntry entry = _cache[path];
    if (entry != null) {
      if (entry.lastModified == lastModified)
        return entry.content;

      _cache.remove(path);
      _cacheSize -= entry.filesize;
    }
  }
  @override
  void setContent(File file, DateTime lastModified, List<int> content) {
    final int filesize = content.length;
    if (shallCache(file, filesize)) {
      final String path = file.path;
      final _CacheEntry entry = _cache[path];
      _cache[path] = new _CacheEntry(content, lastModified, filesize);
      _cacheSize += filesize;
      if (entry != null)
        _cacheSize -= entry.filesize;

      //reduce the cache's size if necessary
      while (_cacheSize > _loader.cacheSize)
        _cacheSize -= _cache.remove(_cache.keys.first).filesize;
    }
  }
}

Future _loadFileAt(HttpConnect connect, String uri, String dir,
    List<String> names, int j, [FileCache cache]) {
  if (j >= names.length)
    throw new Http404(uri);

  final File file = new File(Path.join(dir, names[j]));
  return file.exists().then((exists) {
    return exists ? loadFile(connect, file, cache):
      _loadFileAt(connect, uri, dir, names, j + 1, cache);
  });
}

///Returns false if no need to send the content
bool _checkHeaders(HttpConnect connect, DateTime lastModified, int filesize,
    FileCache cache) {
  final HttpResponse response = connect.response;
  final HttpRequest request = connect.request;
  final HttpHeaders rqheaders = request.headers;
  final String etag = cache != null ? cache.getETag(lastModified, filesize): null;

  //Check If-Match
  final String ifMatch = rqheaders.value(HttpHeaders.IF_MATCH);
  if (ifMatch != null && ifMatch != "*") {
    bool matched = false;
    if (etag != null) {
      for (final String each in ifMatch.split(',')) {
        if (each.trim() == etag) {
          matched = true;
          break;
        }
      }
    }
    if (!matched) {
      response.statusCode = HttpStatus.PRECONDITION_FAILED;
      return false;
    }
  }

  //Check If-None-Match
  //Note: it shall be checked before If-Modified-Since
  final String ifNoneMatch = rqheaders.value(HttpHeaders.IF_NONE_MATCH);
  if (ifNoneMatch != null) {
    bool matched = ifNoneMatch == "*";
    if (!matched && etag != null) {
      for (final String each in ifNoneMatch.split(',')) {
        if (each.trim() == etag) {
          matched = true;
          break;
        }
      }
    }

    if (matched) {
      final String method = request.method;
      if (method == "GET" || method == "HEAD") {
        response.statusCode = HttpStatus.NOT_MODIFIED;
        if (etag != null)
          response.headers.set(HttpHeaders.ETAG, etag);
        return false;
      }
      response.statusCode = HttpStatus.PRECONDITION_FAILED;
      return false;
    }
  }

  //Check If-Modified-Since
  final DateTime ifModifiedSince = rqheaders.ifModifiedSince;
  if (ifModifiedSince != null
  && lastModified.isBefore(ifModifiedSince.add(const Duration(seconds: 1)))) {
    response.statusCode = HttpStatus.NOT_MODIFIED;
    if (etag != null)
      response.headers.set(HttpHeaders.ETAG, etag);
    return false;
  }

  //Check If-Unmodified-Since
  final String value = rqheaders.value(HttpHeaders.IF_UNMODIFIED_SINCE);
  if (value != null) {
    try {
      final DateTime ifUnmodifiedSince = HttpDate.parse(value);
      if (lastModified.isAfter(ifUnmodifiedSince.add(const Duration(seconds: 1)))) {
        response.statusCode = HttpStatus.PRECONDITION_FAILED;
        return false;
      }
    } catch (e) { //ignore it silently
    }
  }
  return true;
}

///Returns false if no need to send the content
bool _setHeaders(HttpConnect connect, File file,
    DateTime lastModified, int filesize,
    FileCache cache, List<_Range> ranges) {
  final HttpResponse response = connect.response;
  final HttpHeaders headers = response.headers;
  headers
      ..set(HttpHeaders.ACCEPT_RANGES, "bytes")
      ..set(HttpHeaders.LAST_MODIFIED, lastModified);

  if (cache != null) {
    final String etag = cache.getETag(lastModified, filesize);
    if (etag != null)
      headers.set(HttpHeaders.ETAG, etag);
    final Duration dur = cache.getExpires(file);
    if (dur != null) {
      headers
        ..set(HttpHeaders.EXPIRES, lastModified.add(dur))
        ..set(HttpHeaders.CACHE_CONTROL, "max-age=${dur.inSeconds}");
    }
  }

  if (connect.request.method == "HEAD"
  || response.statusCode >= HttpStatus.BAD_REQUEST) //error
    return false; //no more processing

  if (ranges == null) {
    response.contentLength = filesize;
  } else {
    response.statusCode = HttpStatus.PARTIAL_CONTENT;
    if (ranges.length == 1) {
      final _Range range = ranges[0];
      response.contentLength = range.length;
      headers.set(HttpHeaders.CONTENT_RANGE,
        "bytes ${range.start}-${range.end - 1}/$filesize");
    } else {
      headers.contentType = _multipartBytesType;
    }
  }

  if (connect.server.chunkedTransferEncoding
  && _isTextType(headers.contentType)) //we compress only text files
    headers.chunkedTransferEncoding = true;
  return true;
}

bool _isTextType(ContentType ctype) {
  String ptype;
  return ctype == null || (ptype = ctype.primaryType) == "text"
    || (ptype == "application" && _textSubtypes.containsKey(ctype.subType));
}
final _textSubtypes = const<String, bool> {
  "json": true, "javascript": true, "dart": true, "xml": true,
  "xhtml+xml": true, "xslt+xml": true,  "rss+xml": true,
  "atom+xml": true, "mathml+xml": true, "svg+xml": true
};

//--- Range Handling ---//
//--- ---//
class _Range {
  ///The start (inclusive).
  final int start;
  ///The end (exclusive).
  final int end;
  final int length;

  factory _Range(int start, int end, int filesize) {
    if (start == null) {
      start = end == null ? 0: filesize - end;
      end = filesize;
    } else {
      end = end == null ? filesize: end + 1; //from inclusive to exclusive
    }
    return new _Range._(start, end, end - start);
  }
  _Range._(this.start, this.end, this.length);

  bool validate(int filesize)
  => start >= 0 && length >= 0 && end <= filesize;
}

List<_Range> _parseRange(HttpConnect connect, int filesize) {
  //TODO: handle If-Range

  final String srange = connect.request.headers.value("range");
  if (srange == null)
    return null;
  if (!srange.startsWith("bytes="))
    return _rangeError(connect);

  List<_Range> ranges = [];
  for (int i = 6;;) {
    final int j = srange.indexOf(',', i);
    final Match matches = _reRange.firstMatch(
      j >= 0 ? srange.substring(i, j): srange.substring(i));
    if (matches == null)
      return _rangeError(connect);

    final List<int> values = new List(2);
    for (int i = 0; i < 2; ++i) {
      final match = matches[i + 1];
      if (!match.isEmpty)
        try {
          values[i] = int.parse(match);
        } catch (ex) {
          return _rangeError(connect);
        }
    }

    final _Range range = new _Range(values[0], values[1], filesize);
    if (!range.validate(filesize)) {
      connect.response.headers.set(HttpHeaders.CONTENT_RANGE, "bytes */$filesize");
      return _rangeError(connect, HttpStatus.REQUESTED_RANGE_NOT_SATISFIABLE);
    }
    ranges.add(range);

    if (j < 0)
      break;
    i = j + 1;
  }
  if (ranges.isEmpty)
    return _rangeError(connect);
  return ranges;
}
_rangeError(HttpConnect connect, [int code = HttpStatus.BAD_REQUEST]) {
  connect.response.statusCode = code;
}
final RegExp _reRange = new RegExp(r"(\d*)\-(\d*)");

typedef Future _WriteRange(_Range range);
class _RangeWriter {
  final HttpResponse response;
  final List<_Range> ranges;
  final String contentType;
  final int filesize;
  final _WriteRange output;

  _RangeWriter(this.response, this.ranges, ContentType contentType,
    this.filesize, this.output): this.contentType = contentType != null ?
      "${HttpHeaders.CONTENT_TYPE}: ${contentType}": null;

  Future write([int j = 0]) {
    if (j >= ranges.length) { //no more
      response
        ..writeln()
        ..write(_MIME_BOUNDARY_END);
      return null; //done
    }

    response
      ..writeln()
      ..writeln(_MIME_BOUNDARY_BEGIN);
    if (contentType != null)
      response.writeln(contentType);

    final _Range range = ranges[j];
    response
      ..writeln("${HttpHeaders.CONTENT_RANGE}: bytes ${range.start}-${range.end - 1}/$filesize")
      ..writeln();
    return output(range).then((_) => write(j + 1));
  }
}

Future _outContentInRanges(HttpResponse response, List<_Range> ranges,
    ContentType contentType, List<int> content) {
  final int filesize = content.length;
  if (ranges == null || ranges.length == 1) {
    final _Range range = ranges != null ? ranges[0]: null;
    response.add(
      range != null && range.length != filesize ?
        content.sublist(range.start, range.end): content);
  } else {
    return new _RangeWriter(response, ranges, contentType, filesize,
      (_Range range) {
        response.add(content.sublist(range.start, range.end));
        return new Future.value();
      }).write();
  }
}

Future _outFileInRanges(HttpResponse response, List<_Range> ranges,
    ContentType contentType, File file, int filesize) {
  if (ranges == null || ranges.length == 1) {
    final _Range range = ranges != null ? ranges[0]: null;
    return response.addStream(
      range != null && range.length != filesize ? 
        file.openRead(range.start, range.end): file.openRead());
  } else {
    //TODO: a better algorithm for reading multiparts of the file
    return new _RangeWriter(response, ranges, contentType, filesize,
        (_Range range)
        => response.addStream(file.openRead(range.start, range.end)))
      .write();
  }
}

//the boundary used for multipart output
const String _MIME_BOUNDARY = "STREAM_MIME_BOUNDARY";
const String _MIME_BOUNDARY_BEGIN = "--$_MIME_BOUNDARY";
const String _MIME_BOUNDARY_END = "--$_MIME_BOUNDARY--";
final ContentType _multipartBytesType =
  ContentType.parse("multipart/byteranges; boundary=$_MIME_BOUNDARY");
