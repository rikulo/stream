//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Oct 09, 2013 11:10:02 AM
// Author: tomyeh
part of stream_plugin;

//--- Cache and Asset Loading ---//
//--- ---//

class _AssetDetail {
  final Asset asset;
  final DateTime lastModified;
  final int assetSize;
  final AssetCache? cache;

  _AssetDetail(this.asset, this.lastModified, this.assetSize, this.cache);

  //Returns the ETAG value, or null if not available.
  late String? etag =
    (cache != null ? cache!.getETag(asset, lastModified, assetSize):
        _getETag(lastModified, assetSize));
}

class _CacheEntry {
  final List<int> content;
  final int assetSize;
  final DateTime lastModified;

  _CacheEntry(this.content, this.lastModified, this.assetSize);
}

class _AssetCache implements AssetCache {
  final AssetLoader _loader;
  final Map<String, _CacheEntry> _cache = new LinkedHashMap<String, _CacheEntry>();
  int _cacheSize = 0;

  _AssetCache(this._loader);

  @override
  String? getETag(Asset asset, DateTime lastModified, int assetSize)
  => _loader.getETag(asset, lastModified, assetSize);
  @override
  Duration? getExpires(Asset asset)
  => _loader.getExpires(asset);

  @override
  bool shallCache(Asset asset, int assetSize)
  => _loader.shallCache(asset, assetSize);
  @override
  List<int>? getContent(Asset asset, DateTime lastModified) {
    final path = asset.path;
    final entry = _cache[path];
    if (entry != null) {
      if (entry.lastModified == lastModified)
        return entry.content;

      _cache.remove(path);
      _cacheSize -= entry.assetSize;
    }
    return null;
  }
  @override
  void setContent(Asset asset, DateTime lastModified, List<int> content) {
    final assetSize = content.length;
    if (shallCache(asset, assetSize)) {
      final path = asset.path;
      final entry = _cache[path];
      if (entry != null)
        _cacheSize -= entry.assetSize;
      _cache[path] = new _CacheEntry(content, lastModified, assetSize);
      _cacheSize += assetSize;

      //reduce the cache's size if necessary
      while (_cacheSize > _loader.cacheSize)
        _cacheSize -= _cache.remove(_cache.keys.first)!.assetSize;
    }
  }
}

Future _loadFileAt(HttpConnect connect, String uri, String dir,
    List<String> names, int j, [AssetCache? cache]) async {
  if (j >= names.length)
    throw new Http404(uri: Uri.tryParse(uri));

  final file = new File(Path.join(dir, names[j]));
  return (await file.exists()) ?
      loadAsset(connect, new FileAsset(file), cache):
      _loadFileAt(connect, uri, dir, names, j + 1, cache);
}

bool _matchETag(String value, String etag) {
  for (int i = 0;;) {
    final j = value.indexOf(',', i);
    if (etag == (j >= 0 ? value.substring(i, j): value.substring(i)).trim())
      return true;
    if (j < 0)
      return false;
    i = j + 1;
  }
}

///Returns false if no need to send the content
bool _setHeaders(HttpConnect connect, _AssetDetail detail, List<_Range>? ranges) {
  final HttpRequest request = connect.request;
  final HttpResponse response = connect.response;
  final HttpHeaders headers = response.headers;
  headers.set(HttpHeaders.acceptRangesHeader, "bytes");

  final bool isPreconditionFailed = response.statusCode == HttpStatus.preconditionFailed;
    //Set by checkIfHeaders (see also Issue 59)
  if (isPreconditionFailed || response.statusCode < HttpStatus.badRequest) {
      headers.set(HttpHeaders.lastModifiedHeader, detail.lastModified);

    if (detail.cache != null) {
      final etag = detail.etag;
      if (etag != null)
        headers.set(HttpHeaders.etagHeader, etag);
      final dur = detail.cache?.getExpires(detail.asset);
      if (dur != null) {
        headers
          ..set(HttpHeaders.expiresHeader, detail.lastModified.add(dur))
          ..set(HttpHeaders.cacheControlHeader, "max-age=${dur.inSeconds}");
      }
    }
  }

  if (request.method == "HEAD" || isPreconditionFailed) 
    return false; //no more processing

  if (ranges == null) {
    response.contentLength = detail.assetSize;
  } else {
    response.statusCode = HttpStatus.partialContent;
    if (ranges.length == 1) {
      final _Range range = ranges[0];
      response.contentLength = range.length;
      headers.set(HttpHeaders.contentRangeHeader,
        "bytes ${range.start}-${range.end - 1}/${detail.assetSize}");
    } else {
      headers.contentType = _multipartBytesType;
    }
  }

  if (request.protocolVersion != "1.0") { //1.1 or later
    headers.chunkedTransferEncoding = _isTextType(headers.contentType); //gzip text only
  }
  return true;
}

String _getETag(DateTime lastModified, int assetSize)
=> '"$assetSize-${lastModified.millisecondsSinceEpoch.toRadixString(16)}"';

bool _isTextType(ContentType? ctype) {
  String ptype, subType;
  return ctype == null || (ptype = ctype.primaryType) == "text"
    || (subType = ctype.subType).endsWith("+xml")
    || (ptype == "application" && _textSubtype.containsKey(subType));
}
const Map<String, bool> _textSubtype = const<String, bool> {
  "json": true, "javascript": true, "dart": true, "xml": true,
};

///used to adjust truncation error when converting to internet time
const Duration _oneSecond = const Duration(seconds: 1);

//--- Range Handling ---//
//--- ---//
class _Range {
  ///The start (inclusive).
  final int start;
  ///The end (exclusive).
  final int end;
  final int length;

  factory _Range(int? start, int? end, int assetSize) {
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

List<_Range>? _parseRange(HttpConnect connect, _AssetDetail detail) {
  final ifRange = connect.headerValue(HttpHeaders.ifRangeHeader);
  if (ifRange != null) {
    try {
      if (detail.lastModified.isAfter(HttpDate.parse(ifRange).add(_oneSecond)))
        return null; //dirty
    } catch (e) { //ignore it silently
    }

    final etag = detail.etag;
    if (etag != null && etag != ifRange.trim())
      return null; //dirty
  }

  final srange = connect.headerValue(HttpHeaders.rangeHeader);
  if (srange == null)
    return null;
  if (!srange.startsWith("bytes="))
    return _rangeError(connect);

  var ranges = <_Range>[];
  for (int i = 6;;) {
    final j = srange.indexOf(',', i);
    final matches = _reRange.firstMatch(
      j >= 0 ? srange.substring(i, j): srange.substring(i));
    if (matches == null)
      return _rangeError(connect);

    final values = <int>[];
    for (int i = 0; i < 2; ++i) {
      final match = matches[i + 1]!;
      if (!match.isEmpty)
        try {
          values.add(int.parse(match));
        } catch (ex) {
          return _rangeError(connect);
        }
    }

    final range = new _Range(values[0], values[1], detail.assetSize);
    if (!range.validate(detail.assetSize)) {
      connect.response.headers.set(
          HttpHeaders.contentRangeHeader, "bytes */${detail.assetSize}");
      return _rangeError(connect, HttpStatus.requestedRangeNotSatisfiable);
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
T? _rangeError<T>(HttpConnect connect, [int code = HttpStatus.badRequest]) {
  connect.response.statusCode = code;
  return null;
}
final RegExp _reRange = new RegExp(r"(\d*)\-(\d*)");

typedef FutureOr _WriteRange(_Range range);
class _RangeWriter {
  final HttpResponse response;
  final List<_Range> ranges;
  final String? contentType;
  final int assetSize;
  final _WriteRange output;

  _RangeWriter(this.response, this.ranges, ContentType? contentType,
    this.assetSize, this.output): this.contentType = contentType != null ?
      "${HttpHeaders.contentTypeHeader}: ${contentType}": null;

  Future write() async {
    for (int j = 0;; ++j) {
      if (j >= ranges.length) { //no more
        response
          ..writeln()
          ..write(_mimeBoundaryEnd);
        return; //done
      }

      response
        ..writeln()
        ..writeln(_mimeBoundaryBegin);
      if (contentType != null)
        response.writeln(contentType);

      final _Range range = ranges[j];
      response
        ..writeln("${HttpHeaders.contentRangeHeader}: bytes ${range.start}-${range.end - 1}/$assetSize")
        ..writeln();
      await output(range);
    }
  }
}

FutureOr _outContentInRanges(HttpResponse response, List<_Range>? ranges,
    ContentType? contentType, List<int> content) {
  final int assetSize = content.length;
  if (ranges == null || ranges.length == 1) {
    final range = ranges != null ? ranges[0]: null;
    response.add(
      range != null && range.length != assetSize ?
        content.sublist(range.start, range.end): content);
    return null;
  } else {
    return new _RangeWriter(response, ranges, contentType, assetSize,
      (range) {
        response.add(content.sublist(range.start, range.end));
      }).write();
  }
}

Future _outAssetInRanges(HttpResponse response, List<_Range>? ranges,
    ContentType? contentType, Asset asset, int assetSize) {
  if (ranges == null || ranges.length == 1) {
    final range = ranges?[0];
    return response.addStream(
      range != null && range.length != assetSize ? 
        asset.openRead(range.start, range.end): asset.openRead());
  } else {
    //TODO: a better algorithm for reading multiparts of the asset
    return new _RangeWriter(response, ranges, contentType, assetSize,
        (range) => response.addStream(asset.openRead(range.start, range.end)))
      .write();
  }
}

//the boundary used for multipart output
const String _mimeBoundary = "STREAM_MIME_BOUNDARY";
const String _mimeBoundaryBegin = "--$_mimeBoundary";
const String _mimeBoundaryEnd = "--$_mimeBoundary--";
final ContentType _multipartBytesType =
  ContentType.parse("multipart/byteranges; boundary=$_mimeBoundary");
