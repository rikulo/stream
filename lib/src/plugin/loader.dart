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
  void load(HttpConnex connex, String uri);
}

/** A file-system-based resource loader.
 */
class FileLoader implements ResourceLoader {
  FileLoader(Path this.rootDir);

  @override
  final Path rootDir;

  //@override
  void load(HttpConnex connex, String uri) {
    if (uri == null)
      throw new Http404();
    var path = uri.startsWith('/') ? uri.substring(1): uri;
    if (path.startsWith("webapp/") || path == "webapp")
      throw new Http403(uri);
    path = rootDir.append(path);

    var file = new File.fromPath(path);
    safeThen(file.exists(), connex, (exists) {
      if (exists) {
        loadFile(connex, file);
        return;
      }

      //try uri / indexNames
      final dir = new Directory.fromPath(path);
      safeThen(dir.exists(), connex, (exists) {
        if (exists)
          _loadFirstFile(connex, uri, path, new List.from(connex.server.indexNames));
        else
          throw new Http404(uri);
      });
    });
  }
}

bool _loadFirstFile(HttpConnex connex, String uri, Path dir, List names) {
  if (names.isEmpty)
    throw new Http404(uri);

  final nm = names.removeAt(0);
  final file = new File.fromPath(dir.append(nm));
  safeThen(file.exists(), connex, (exists) {
    if (exists)
      loadFile(connex, file);
    else
      _loadFirstFile(connex, uri, dir, names);
  });
}

/** Loads a file into the given response.
 * Notice that this method assumes the file exists.
 */
void loadFile(HttpConnex connex, File file) {
  //TODO: handle headers
  final headers = connex.response.headers;
  final ctype = contentTypes[new Path(file.name).extension];
  if (ctype != null)
    headers.contentType = ctype;

  //write content
  final out = connex.response.outputStream;
  file.openInputStream()
    ..onError = connex.error
    ..pipe(out, close: true);
}
