//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Thu, Jan 10, 2013  4:47:50 PM
// Author: tomyeh
part of stream_plugin;

/**
 * Resource loader.
 */
abstract class ResourceLoader {
  factory ResourceLoader(String rootDir)
  => new FileLoader(rootDir);

  /** The root directory.
   */
  final String rootDir;

  /** Loads the resource of the given URI to the given response.
   */
  Future load(HttpConnect connect, String uri);
}

/** A file cache. It is used by [FileLoader].
 */
abstract class FileCache {
  /** Returns the value of the ETag header. If null is returned, ETag header
   * won't be generated.
   */
  String getETag(DateTime lastModified, int filesize);
  /** Returns the duration for the Expires and max-age headers.
   * If null is returned, the Expires and max-age headers won't be generated.
   */
  Duration getExpires(File file);

  /** Whether the given file shall be cached.
   *
   * * [filesize] - the size of [file] in bytes.
   */
  bool shallCache(File file, int filesize);
  ///Returns the content of file, or null if not cached or expires (unit: bytes) .
  List<int> getContent(File file, DateTime lastModified);
  ///Stores the content of the file (unit: bytes) into the cache.
  void setContent(File file, DateTime lastModified, List<int> content);
}

/** A file-system-based resource loader.
 */
class FileLoader implements ResourceLoader {
  FileLoader(this.rootDir) {
    _cache = new _FileCache(this);
  }

  @override
  final String rootDir;

  /** The total cache size (unit: bytes). Default: 2 * 1024 * 1024.
   * Note: [cacheSize] must be larger than [cacheThreshold].
   * Otherwise, result is unpreditable.
   */
  int cacheSize = 2 * 1024 * 1024;
  ///The thread hold (unit: bytes) to cache. Only files less than this size
  ///will be cached. Default: 96 * 1024.
  int cacheThreshold = 96 * 1024;
  FileCache _cache;

  ///Whether to generate the ETag header. Default: true.
  bool useETag = true;
  ///Whether to generate the Expires and max-age headers. Default: true.
  bool useExpires = true;

  /** Returns the value of the ETag header.
   * If null is returned, ETag header won't be generated.
   *
   * Default: a string combining [lastModified] and [filesize]
   * if [useEtag] is true.
   * You can override this method if necessary.
   */
  String getETag(DateTime lastModified, int filesize)
  => useETag ? 'W/"$filesize-${lastModified.millisecondsSinceEpoch}"': null;
  /** Returns the duration for the Expires and max-age headers.
   * If null is returned, the Expires and max-age headers won't be generated.
   *
   * Default: 30 days if [useExpres] is true.
   * You can override this method if necessary.
   */
  Duration getExpires(File file) => useExpires ? const Duration(days: 30): null;

  /** Whether the given file shall be cached.
   *
   * Default: it returns true if [filesize] is not greater than [cacheThreshold].
   * You override this method if necessary.
   *
   * * [filesize] - the size of [file] in bytes.
   */
  bool shallCache(File file, int filesize) => filesize <= cacheThreshold;

  @override
  Future load(HttpConnect connect, String uri) {
    var path = uri.substring(1); //must start with '/'
    path = Path.join(rootDir, path);

    var file = new File(path);
    return file.exists().then((exists) {
      if (exists)
        return loadFile(connect, file, _cache);
      return new Directory(path).exists().then((exists) {
        if (exists)
          return _loadFileAt(connect, uri, path, connect.server.indexNames, 0, _cache);
        throw new Http404(uri);
      });
    });
  }
}

/** Loads a file into the given response.
 * Notice that this method assumes the file exists.
 */
Future loadFile(HttpConnect connect, File file, [FileCache cache]) {
  final HttpResponse response = connect.response;
  final bool isIncluded = connect.isIncluded;
  ContentType contentType;
  if (!isIncluded) {
    final ext = Path.extension(file.path);
    if (!ext.isEmpty) {
      contentType = contentTypes[ext.substring(1)];
      if (contentType != null)
        response.headers.contentType = contentType;
    }
  }

  return file.lastModified().then((DateTime lastModified) {
    List<_Range> ranges;
    if (cache != null) {
      final List<int> content = cache.getContent(file, lastModified);
      if (content != null) {
        final int filesize = content.length;
        if (!isIncluded) {
          if (!_checkHeaders(connect, lastModified, filesize, cache))
            return;

          ranges = _parseRange(connect, filesize);
          if (!_setHeaders(connect, file, lastModified, filesize, cache, ranges))
            return; //done
        }
        return _outContentInRanges(response, ranges, contentType, content);
      }
    }

    return file.length().then((int filesize) {
      if (!isIncluded) {
        if (!_checkHeaders(connect, lastModified, filesize, cache))
          return;

        ranges = _parseRange(connect, filesize);
        if (!_setHeaders(connect, file, lastModified, filesize, cache, ranges))
          return; //done
      }

      if (cache != null && cache.shallCache(file, filesize))
        return file.readAsBytes().then((List<int> content) {
          cache.setContent(file, lastModified, content);
          return _outContentInRanges(response, ranges, contentType, content);
        });

      return _outFileInRanges(response, ranges, contentType, file, filesize);
    });
  });
}
