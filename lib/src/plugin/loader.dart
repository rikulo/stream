//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Thu, Jan 10, 2013  4:47:50 PM
// Author: tomyeh
part of stream_plugin;

/**
 * Resource loader.
 *
 * There are two alternatives to implement it. First, implement this interface
 * directly from scratch. Optionally, invoke [loadAsset] for handling HTTP
 * requirements, such as partial content, ETag and so on.
 *
 * Second, you can extend from [AssetLoader] by overriding
 * the [getAsset] method. In additions to handling HTTP requirements,
 * [AsssetLoader] also provides a caching mechanism to speed up the
 * loading.
 */
abstract class ResourceLoader {
  factory ResourceLoader(String rootDir)
  => new FileLoader(rootDir);

  /** The root directory.
   */
  final String rootDir;

  /** Loads the asset of the given URI to the given response.
   */
  Future load(HttpConnect connect, String uri);
}

/** An asset (aka., resource), such as a file or a BLOB object in database.
 *
 * > Note: It is used by [loadAsset] and [AssetLoader] (and derives).
 * > [ResourceLoader] doesn't depend on it.
 */
abstract class Asset {
  ///The path uniquely identifies this asset.
  ///It must be unique in the scope of [AssetLoader].
  String get path;

  /** When this asset was last modified.
   *
   * Throws an exception if failed.
   */
  Future<DateTime> lastModified();
  /** The length of this asset.
   *
   * Throws an exception if failed.
   */
  Future<int> length();

  /** Create a new independent Stream for the contents of this asset.
   *
   * * [start] - the starting offset (inclusive)
   * * [end] - the ending offset (exclusive)
   */
  Stream<List<int>> openRead([int start, int end]);
  ///Read the entire asset's contents as a list of bytes.
  Future<List<int>> readAsBytes();
}

/** A cache for storing resources.
 *
 * > Note: It is used by [loadAsset] and [AssetLoader] and derives.
 * > [ResourceLoader] doesn't depend on it.
 */
abstract class AssetCache {
  /** Returns the value of the ETag header. If null is returned, ETag header
   * won't be generated.
   */
  String getETag(Asset asset, DateTime lastModified, int assetSize);
  /** Returns the duration for the Expires and max-age headers.
   * If null is returned, the Expires and max-age headers won't be generated.
   */
  Duration getExpires(Asset asset);

  /** Whether the given asset shall be cached.
   *
   * * [assetSize] - the size of [asset] in bytes.
   */
  bool shallCache(Asset asset, int assetSize);
  ///Returns the content of asset, or null if not cached or expires (unit: bytes) .
  List<int> getContent(Asset asset, DateTime lastModified);
  ///Stores the content of the asset (unit: bytes) into the cache.
  void setContent(Asset asset, DateTime lastModified, List<int> content);
}

/** A skeletal implementation of [ResourceLoader] that utilizes
 * [AssetCache] and supports all HTTP requirements such as
 * partial content, multi-part loading, ETag and more.
 *
 * To implement your own loader, you can do the follows:
 *
 * 1. Implements [Asset] to load your asset.
 * 2. Extends [AssetLoader] and override [getAsset] to return
 * the [Asset] object you implemented for the given path.
 *
 * > Note: [rootDir] is not used in [AssetLoader]. Whether
 * it is meaningful depends on how [getAsset] is implemented in derives.
 */
abstract class AssetLoader implements ResourceLoader {
  AssetLoader([this.rootDir]) {
    _cache = new _AssetCache(this);
  }

  @override
  final String rootDir;

  /** The total cache size (unit: bytes). Default: 3 * 1024 * 1024.
   * Note: [cacheSize] must be larger than [cacheThreshold].
   * Otherwise, result is unpredictable.
   */
  int cacheSize = 3 * 1024 * 1024;
  /** The thread hold (unit: bytes) to cache. Only resources less than this size
   * will be cached. Default: 128 * 1024.
   */
  int cacheThreshold = 128 * 1024;

  /** The cache.
   */
  AssetCache get cache => _cache;
  AssetCache _cache;

  ///Whether to generate the ETag header. Default: true.
  bool useETag = true;
  ///Whether to generate the Expires and max-age headers. Default: true.
  bool useExpires = true;

  /** Returns the value of the ETag header.
   * If null is returned, ETag header won't be generated.
   *
   * Default: a string combining [lastModified] and [assetSize]
   * if [useEtag] is true.
   * You can override this method if necessary.
   */
  String getETag(Asset asset, DateTime lastModified, int assetSize)
  => useETag ? _getETag(lastModified, assetSize): null;
  /** Returns the duration for the Expires and max-age headers.
   * If null is returned, the Expires and max-age headers won't be generated.
   *
   * Default: 30 days if [useExpres] is true.
   * You can override this method if necessary.
   */
  Duration getExpires(Asset asset) => useExpires ? const Duration(days: 30): null;

  /** Whether the given asset shall be cached.
   *
   * Default: it returns true if [assetSize] is not greater than [cacheThreshold].
   * You override this method if necessary.
   *
   * * [assetSize] - the size of [asset] in bytes.
   */
  bool shallCache(Asset asset, int assetSize) => assetSize <= cacheThreshold;

  /** Returns the [Asset] instance representing [path].
   *
   * The derives must override this method.
   */
  Asset getAsset(String path);

  @override
  Future load(HttpConnect connect, String uri)
  => loadAsset(connect, getAsset(uri), _cache);
}
/** A file-system-based asset loader.
 */
class FileLoader extends AssetLoader {
  FileLoader(String rootDir): super(rootDir);

  @override
  Asset getAsset(String path)
  => new _FileAsset(new File(path));

  @override
  Future load(HttpConnect connect, String uri) {
    String path = uri.substring(1); //must start with '/'
    path = Path.join(rootDir, path);

    final File file = new File(path);
    return file.exists().then((bool exists) {
      if (exists)
        return loadAsset(connect, new _FileAsset(file), _cache);
      return new Directory(path).exists().then((bool exists) {
        if (exists)
          return _loadFileAt(connect, uri, path, connect.server.indexNames, 0, _cache);
        throw new Http404(uri);
      });
    });
  }
}

/** Loads an asset into the given response.
 * Notice that this method assumes the asset exists.
 */
Future loadAsset(HttpConnect connect, Asset asset, [AssetCache cache]) {
  final HttpResponse response = connect.response;
  final bool isIncluded = connect.isIncluded;
  ContentType contentType;
  if (!isIncluded) {
    final ext = Path.extension(asset.path);
    if (!ext.isEmpty) {
      contentType = getContentType(ext.substring(1));
      if (contentType != null)
        response.headers.contentType = contentType;
    }
  }

  DateTime lastModified;
  List<int> content;

  return asset.lastModified()
  .catchError((ex) {
    throw new Http404.fromConnect(connect);
  })
  .then((_) {
    lastModified = _;
    if (cache != null) {
      content = cache.getContent(asset, lastModified);
      if (content != null)
        return content.length;
    }
    return asset.length();
  })
  .then((int assetSize) {
    List<_Range> ranges;

    if (!isIncluded) {
      final _AssetDetail detail =
        new _AssetDetail(asset, lastModified, assetSize, cache);
      if (!checkIfHeaders(connect, lastModified, detail.etag))
        return null;

      ranges = _parseRange(connect, detail);
      if (!_setHeaders(connect, detail, ranges))
        return null; //done
    }

    if (content != null)
      return _outContentInRanges(response, ranges, contentType, content);

    if (cache != null && cache.shallCache(asset, assetSize))
      return asset.readAsBytes().then((List<int> content) {
        cache.setContent(asset, lastModified, content);
        return _outContentInRanges(response, ranges, contentType, content);
      });

    return _outAssetInRanges(response, ranges, contentType, asset, assetSize);
  });
}

/**
 * Check if the conditions specified in the optional If headers are
 * satisfied, such as `If-Modified-Since` and `If-None-Match` headers.
 *
 * If false is returned, the caller shall stop from generating further content.
 *
 * * [lastModified] - when it was last modified. Ignored if null.
 * * [etag] - the ETag. Ignored if null.
 */
bool checkIfHeaders(HttpConnect connect, DateTime lastModified, String etag) {
  final HttpResponse response = connect.response;
  if (response.statusCode >= 300)
    return true; //Ignore If, since caused by forward-by-error (see also Issue 59)

  final HttpRequest request = connect.request;
  final HttpHeaders rqheaders = request.headers;

  //Check If-Match
  final String ifMatch = rqheaders.value(HttpHeaders.IF_MATCH);
  if (ifMatch != null && ifMatch != "*"
  && (etag == null || !_matchETag(ifMatch, etag))) { //not match
    response.statusCode = HttpStatus.PRECONDITION_FAILED;
    return false;
  }

  //Check If-None-Match
  //Note: it shall be checked before If-Modified-Since
  final String ifNoneMatch = rqheaders.value(HttpHeaders.IF_NONE_MATCH);
  if (ifNoneMatch != null) {
    if (ifNoneMatch == "*"
    || (etag != null && _matchETag(ifNoneMatch, etag))) { //match
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

  if (lastModified != null) {
    //Check If-Modified-Since
    //Ignored, if If-None-Match specified (since ETag differs)
    final DateTime ifModifiedSince = rqheaders.ifModifiedSince;
    if (ifModifiedSince != null && ifNoneMatch == null
    && lastModified.isBefore(ifModifiedSince.add(_ONE_SECOND))) {
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
        if (lastModified.isAfter(ifUnmodifiedSince.add(_ONE_SECOND))) {
          response.statusCode = HttpStatus.PRECONDITION_FAILED;
          return false;
        }
      } catch (e) { //ignore it silently
      }
    }
  }
  return true;
}
