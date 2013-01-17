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
   *
   * Notice that, if [success] is specified, it the connection won't be closed,
   * and no HTTP header will be generated.
   */
  void load(HttpConnect connect, String uri, {success()});
}

/** A file-system-based resource loader.
 */
class FileLoader implements ResourceLoader {
  FileLoader(Path this.rootDir);

  @override
  final Path rootDir;

  //@override
  void load(HttpConnect connect, String uri, {success()}) {
    var path = uri.substring(1); //must start with '/'
    path = rootDir.append(path);

    var file = new File.fromPath(path);
    connect.then(file.exists(), (exists) {
      if (exists) {
        loadFile(connect, file, success: success);
        return;
      }

      //try uri / indexNames
      final dir = new Directory.fromPath(path);
      connect.then(dir.exists(), (exists) {
        if (exists)
          _loadFileAt(connect, uri, path, connect.server.indexNames, 0, success);
        else
          throw new Http404(uri);
      });
    });
  }
}

bool _loadFileAt(HttpConnect connect, String uri, Path dir, List<String> names, int j,
  success()) {
  if (j >= names.length)
    throw new Http404(uri);

  final file = new File.fromPath(dir.append(names[j]));
  connect.then(file.exists(), (exists) {
    if (exists)
      loadFile(connect, file, success: success);
    else
      _loadFileAt(connect, uri, dir, names, j + 1, success);
  });
}

/** Loads a file into the given response.
 * Notice that this method assumes the file exists.
 *
 * Also notice that if [success] is specified, it won't generate any HTTP headers.
 */
void loadFile(HttpConnect connect, File file, {success()}) {
  if (success != null) {
    file.openInputStream()
      ..onError = connect.error
      ..onClosed = success
      ..pipe(connect.response.outputStream, close: false);
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

      //write content
      file.openInputStream()
        ..onError = connect.error
        ..pipe(connect.response.outputStream, close: true);
    });
  });

}
