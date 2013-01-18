//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Thu, Jan 10, 2013  4:47:50 PM
// Author: tomyeh
part of stream_plugin;

/**
 * Resource loader.
 */
abstract class ResourceLoader {
  factory ResourceLoader(Path rootDir)
  => new FileLoader(rootDir);

  /** The root directory.
   */
  final Path rootDir;

  /** Loads the resource of the given URI to the given response.
   */
  void load(HttpConnect connect, String uri);
}

/** A file-system-based resource loader.
 */
class FileLoader implements ResourceLoader {
  FileLoader(Path this.rootDir);

  @override
  final Path rootDir;

  //@override
  void load(HttpConnect connect, String uri) {
    var path = uri.substring(1); //must start with '/'
    path = rootDir.append(path);

    var file = new File.fromPath(path);
    connect.then(file.exists(), (exists) {
      if (exists) {
        loadFile(connect, file);
        return;
      }

      //try uri / indexNames
      final dir = new Directory.fromPath(path);
      connect.then(dir.exists(), (exists) {
        if (exists)
          _loadFileAt(connect, uri, path, connect.server.indexNames, 0);
        else
          throw new Http404(uri);
      });
    });
  }
}

bool _loadFileAt(HttpConnect connect, String uri, Path dir, List<String> names, int j) {
  if (j >= names.length)
    throw new Http404(uri);

  final file = new File.fromPath(dir.append(names[j]));
  connect.then(file.exists(), (exists) {
    if (exists)
      loadFile(connect, file);
    else
      _loadFileAt(connect, uri, dir, names, j + 1);
  });
}

/** Loads a file into the given response.
 * Notice that this method assumes the file exists.
 */
void loadFile(HttpConnect connect, File file) {
  if (connect.isIncluded) {
    _loadFile(connect, file);
    return;
  }

  final headers = connect.response.headers;
  final ctype = contentTypes[new Path(file.name).extension];
  if (ctype != null)
    headers.contentType = ctype;

  connect.then(file.length(), (length) {
    connect.response.contentLength = length;

    connect.then(file.lastModified(), (date) {
      headers.add(HttpHeaders.LAST_MODIFIED, date);
      _loadFile(connect, file);
    });
  });
}

void _loadFile(HttpConnect connect, File file) {
  file.openInputStream()
    ..onError = connect.error
    ..onClosed = connect.close
    ..pipe(connect.response.outputStream, close: false);
}
