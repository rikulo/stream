//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Oct 09, 2013 11:10:02 AM
// Author: tomyeh
part of stream_plugin;

//--- Cache and Asset Loading ---//
//--- ---//

class _FileAsset implements Asset {
  _FileAsset(this.file);

  final File file;

  @override
  String get path => file.path;
  @override
  Future<DateTime> lastModified() => file.lastModified();
  @override
  Future<int> length() => file.length();
  @override
  Stream<List<int>> openRead([int start, int end]) => file.openRead(start, end);
  @override
  Future<List<int>> readAsBytes() => file.readAsBytes();
}

class _AssetDetail {
  final Asset asset;
  final DateTime lastModified;
  final int assetSize;
  final AssetCache cache;

  _AssetDetail(this.asset, this.lastModified, this.assetSize, this.cache);

  //Returns the ETAG value, or null if not available.
  String get etag
  => _etag != null ? _etag:
    (_etag = cache != null ? cache.getETag(asset, lastModified, assetSize):
        _getETag(lastModified, assetSize));
  String _etag;
}

class _CacheEntry {
  final List<int> content;
  final int assetSize;
  final DateTime lastModified;

  _CacheEntry(this.content, this.lastModified, this.assetSize);
}

class _AssetCache implements AssetCache {
  final AssetLoader _loader;
  final Map<String, _CacheEntry> _cache = new LinkedHashMap();
  int _cacheSize = 0;

  _AssetCache(this._loader);

  @override
  String getETag(Asset asset, DateTime lastModified, int assetSize)
  => _loader.getETag(asset, lastModified, assetSize);
  @override
  Duration getExpires(Asset asset)
  => _loader.getExpires(asset);

  @override
  bool shallCache(Asset asset, int assetSize)
  => _loader.shallCache(asset, assetSize);
  @override
  List<int> getContent(Asset asset, DateTime lastModified) {
    final String path = asset.path;
    final _CacheEntry entry = _cache[path];
    if (entry != null) {
      if (entry.lastModified == lastModified)
        return entry.content;

      _cache.remove(path);
      _cacheSize -= entry.assetSize;
    }
  }
  @override
  void setContent(Asset asset, DateTime lastModified, List<int> content) {
    final int assetSize = content.length;
    if (shallCache(asset, assetSize)) {
      final String path = asset.path;
      final _CacheEntry entry = _cache[path];
      _cache[path] = new _CacheEntry(content, lastModified, assetSize);
      _cacheSize += assetSize;
      if (entry != null)
        _cacheSize -= entry.assetSize;

      //reduce the cache's size if necessary
      while (_cacheSize > _loader.cacheSize)
        _cacheSize -= _cache.remove(_cache.keys.first).assetSize;
    }
  }
}

Future _loadFileAt(HttpConnect connect, String uri, String dir,
    List<String> names, int j, [AssetCache cache]) {
  if (j >= names.length)
    throw new Http404(uri);

  final File file = new File(Path.join(dir, names[j]));
  return file.exists().then((exists) {
    return exists ? loadAsset(connect, new _FileAsset(file), cache):
      _loadFileAt(connect, uri, dir, names, j + 1, cache);
  });
}

bool _matchETag(String value, String etag) {
  for (int i = 0;;) {
    final int j = value.indexOf(',', i);
    if (etag == (j >= 0 ? value.substring(i, j): value.substring(i)).trim())
      return true;
    if (j < 0)
      return false;
    i = j + 1;
  }
}

///Returns false if no need to send the content
bool _setHeaders(HttpConnect connect, _AssetDetail detail, List<_Range> ranges) {
  final HttpResponse response = connect.response;
  final HttpHeaders headers = response.headers;
  headers.set(HttpHeaders.ACCEPT_RANGES, "bytes");

  final bool isPreconditionFailed = response.statusCode == HttpStatus.PRECONDITION_FAILED;
    //Set by checkIfHeaders (see also Issue 59)
  if (isPreconditionFailed || response.statusCode < HttpStatus.BAD_REQUEST) {
      headers.set(HttpHeaders.LAST_MODIFIED, detail.lastModified);

    if (detail.cache != null) {
      final String etag = detail.etag;
      if (etag != null)
        headers.set(HttpHeaders.ETAG, etag);
      final Duration dur = detail.cache.getExpires(detail.asset);
      if (dur != null) {
        headers
          ..set(HttpHeaders.EXPIRES, detail.lastModified.add(dur))
          ..set(HttpHeaders.CACHE_CONTROL, "max-age=${dur.inSeconds}");
      }
    }
  }

  if (connect.request.method == "HEAD" || isPreconditionFailed) 
    return false; //no more processing

  if (ranges == null) {
    response.contentLength = detail.assetSize;
  } else {
    response.statusCode = HttpStatus.PARTIAL_CONTENT;
    if (ranges.length == 1) {
      final _Range range = ranges[0];
      response.contentLength = range.length;
      headers.set(HttpHeaders.CONTENT_RANGE,
        "bytes ${range.start}-${range.end - 1}/${detail.assetSize}");
    } else {
      headers.contentType = _multipartBytesType;
    }
  }

  if (connect.server.chunkedTransferEncoding
  && _isTextType(headers.contentType)) //we compress only text files
    headers.chunkedTransferEncoding = true;
  return true;
}

String _getETag(DateTime lastModified, int assetSize)
=> 'W/"$assetSize-${lastModified.millisecondsSinceEpoch}"';

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
///used to adjust truncation error when converting to internet time
const Duration _ONE_SECOND = const Duration(seconds: 1);

//--- Range Handling ---//
//--- ---//
class _Range {
  ///The start (inclusive).
  final int start;
  ///The end (exclusive).
  final int end;
  final int length;

  factory _Range(int start, int end, int assetSize) {
    if (start == null) {
      start = end == null ? 0: assetSize - end;
      end = assetSize;
    } else {
      end = end == null ? assetSize: end + 1; //from inclusive to exclusive
    }
    return new _Range._(start, end, end - start);
  }
  _Range._(this.start, this.end, this.length);

  bool validate(int assetSize)
  => start >= 0 && length >= 0 && end <= assetSize;
}

List<_Range> _parseRange(HttpConnect connect, _AssetDetail detail) {
  final HttpHeaders rqheaders = connect.request.headers;
  final String ifRange = rqheaders.value(HttpHeaders.IF_RANGE);
  if (ifRange != null) {
    try {
      if (detail.lastModified.isAfter(HttpDate.parse(ifRange).add(_ONE_SECOND)))
        return null; //dirty
    } catch (e) { //ignore it silently
    }

    final String etag = detail.etag;
    if (etag != null && etag != ifRange.trim())
      return null; //dirty
  }

  final String srange = rqheaders.value(HttpHeaders.RANGE);
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

    final _Range range = new _Range(values[0], values[1], detail.assetSize);
    if (!range.validate(detail.assetSize)) {
      connect.response.headers.set(
          HttpHeaders.CONTENT_RANGE, "bytes */${detail.assetSize}");
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
  final int assetSize;
  final _WriteRange output;

  _RangeWriter(this.response, this.ranges, ContentType contentType,
    this.assetSize, this.output): this.contentType = contentType != null ?
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
      ..writeln("${HttpHeaders.CONTENT_RANGE}: bytes ${range.start}-${range.end - 1}/$assetSize")
      ..writeln();
    return output(range).then((_) => write(j + 1));
  }
}

Future _outContentInRanges(HttpResponse response, List<_Range> ranges,
    ContentType contentType, List<int> content) {
  final int assetSize = content.length;
  if (ranges == null || ranges.length == 1) {
    final _Range range = ranges != null ? ranges[0]: null;
    response.add(
      range != null && range.length != assetSize ?
        content.sublist(range.start, range.end): content);
  } else {
    return new _RangeWriter(response, ranges, contentType, assetSize,
      (_Range range) {
        response.add(content.sublist(range.start, range.end));
        return new Future.value();
      }).write();
  }
}

Future _outAssetInRanges(HttpResponse response, List<_Range> ranges,
    ContentType contentType, Asset asset, int assetSize) {
  if (ranges == null || ranges.length == 1) {
    final _Range range = ranges != null ? ranges[0]: null;
    return response.addStream(
      range != null && range.length != assetSize ? 
        asset.openRead(range.start, range.end): asset.openRead());
  } else {
    //TODO: a better algorithm for reading multiparts of the asset
    return new _RangeWriter(response, ranges, contentType, assetSize,
        (_Range range)
        => response.addStream(asset.openRead(range.start, range.end)))
      .write();
  }
}

//the boundary used for multipart output
const String _MIME_BOUNDARY = "STREAM_MIME_BOUNDARY";
const String _MIME_BOUNDARY_BEGIN = "--$_MIME_BOUNDARY";
const String _MIME_BOUNDARY_END = "--$_MIME_BOUNDARY--";
final ContentType _multipartBytesType =
  ContentType.parse("multipart/byteranges; boundary=$_MIME_BOUNDARY");
