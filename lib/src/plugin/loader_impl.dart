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
bool _setHeaders(HttpConnect connect, File file,
    DateTime lastModified, int filesize,
    FileCache cache, _Range range) {
  connect.response.contentLength = range != null ? range.length: filesize;

  final HttpHeaders headers = connect.response.headers;
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

  if (connect.request.method == "HEAD")
    return false; //no more processing

  if (range != null) {
    connect.response.statusCode = HttpStatus.PARTIAL_CONTENT;
    headers.set(HttpHeaders.CONTENT_RANGE,
      "bytes ${range.start}-${range.end - 1}/$filesize");
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
    if (start < 0) start = 0;
    if (start > filesize) start = filesize;
    if (end < start) end = start;
    if (end > filesize) end = filesize;
    return new _Range._(start, end, end - start);
  }
  _Range._(this.start, this.end, this.length);
}

_Range _parseRange(HttpConnect connect, int filesize) {
  //TODO: handle If-Range
  //TODO: handle multiple ranges (mutlipart/byteranges; boundary=...)

  final String range = connect.request.headers.value("range");
  if (range == null)
    return null;

  final Match matches = _reRange.firstMatch(range);
  if (matches == null)
    return _badRequest(connect);

  final List<int> values = new List(2);
  for (int i = 0; i < 2; ++i) {
    final match = matches[i + 1];
    if (!match.isEmpty)
      try {
        values[i] = int.parse(match);
      } catch (ex) {
        return _badRequest(connect);
      }
  }
  return new _Range(values[0], values[1], filesize);
}
_badRequest(HttpConnect connect) {
  connect.response.statusCode = HttpStatus.BAD_REQUEST;
}
final RegExp _reRange = new RegExp(r"^bytes=(\d*)\-(\d*)$");
