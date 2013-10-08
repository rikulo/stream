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
  ///The value of the etag header, or null if not available.
  String get etag;

  ///Whether a file shall be cached with the given filesize.
  bool shallCache(int filesize);
  ///Returns the content of file, or null if not cached or expires (unit: bytes) .
  List<int> getContent(File file, DateTime lastModified, int filesize);
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
  ///The value of the etag header. Ignored if null (default).
  String etag;

  /** The total cache size (unit: bytes). Default: 500KB.
   * Note: [cacheSize] must be larger than [cacheThreshold].
   * Otherwise, result is unpreditable.
   */
  int cacheSize = 500 * 1024;
  ///The threadhold (unit: bytes) to cache. Only files less than this size
  ///will be cached. Default: 50KB.
  int cacheThreshold = 50 * 1024;
  FileCache _cache;

  @override
  Future load(HttpConnect connect, String uri) {
    var path = uri.substring(1); //must start with '/'
    path = Path.join(rootDir, path);

    var file = new File(path);
    return file.exists().then((exists) {
      if (!exists)
        return new Directory(path).exists();
      return loadFile(connect, file, _cache);
    }).then((exists) {
      if (exists is bool) { //null or other value means done (i.e., returned by loadFile)
        if (exists)
          return _loadFileAt(connect, uri, path, connect.server.indexNames, 0, _cache);
        throw new Http404(uri);
      }
    });
  }
}

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
  bool shallCache(int filesize) => filesize <= _loader.cacheThreshold;
  @override
  String get etag => _loader.etag;
  @override
  List<int> getContent(File file, DateTime lastModified, int filesize) {
    final String path = file.path;
    final _CacheEntry entry = _cache[path];
    if (entry != null) {
      if (entry.filesize == filesize && entry.lastModified == lastModified)
        return entry.content;

      _cache.remove(path);
      _cacheSize -= entry.filesize;
    }
  }
  @override
  void setContent(File file, DateTime lastModified, List<int> content) {
    final int filesize = content.length;
    if (shallCache(filesize)) {
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

/** Loads a file into the given response.
 * Notice that this method assumes the file exists.
 */
Future loadFile(HttpConnect connect, File file, [FileCache cache]) {
  final headers = connect.response.headers;
  final bool isIncluded = connect.isIncluded;
  if (!isIncluded) {
    final ctype = contentTypes[Path.extension(file.path)];
    if (ctype != null)
      headers.contentType = ctype;
  }

  int filesize;
  return file.length().then((_) {
    filesize = _;
    if (!isIncluded)
      connect.response.contentLength = filesize;
    return file.lastModified();
  }).then((DateTime lastModified) {
    if (!isIncluded) {
      headers
        ..set(HttpHeaders.LAST_MODIFIED, lastModified)
        ..set(HttpHeaders.ETAG, cache != null && cache.etag != null ?
          cache.etag: 'W/"$filesize-${lastModified.millisecondsSinceEpoch}"');

      if (connect.server.chunkedTransferEncoding
      && _isTextType(headers.contentType)) //we compress only text files
        headers.chunkedTransferEncoding = true;
    }

    if (cache != null) {
      final List<int> content = cache.getContent(file, lastModified, filesize);
      if (content != null) {
        connect.response.add(content);
        return;
      }

      if (cache.shallCache(filesize))
        return file.readAsBytes().then((List<int> content) {
          cache.setContent(file, lastModified, content);
          connect.response.add(content);
        });
    }

    return _loadFile(connect, file);
  });
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

Future _loadFile(HttpConnect connect, File file)
=> connect.response.addStream(file.openRead()); //returns Future<HttpResponse>
