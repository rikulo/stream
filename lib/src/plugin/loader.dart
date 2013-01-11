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

  /** Loads the resource of the given path to the given response.
   */
  void load(HttpConnex connex, String path);
}

/** A file-system-based resource loader.
 */
class FileLoader implements ResourceLoader {
  FileLoader(Path this.rootDir);

  @override
  final Path rootDir;

  //@override
  void load(HttpConnex connex, String path) {
    if (path == null)
      throw new Http404();
    var p = path.startsWith('/') ? path.substring(1): path;
    if (p.startsWith("webapp/") || p == "webapp")
      throw new Http403(path);
    p = rootDir.append(p);

    var file = new File.fromPath(p);
    safeThen(file.exists(), connex, (exists) {
      if (exists) {
        loadFile(connex, file);
        return;
      }

      //try path / indexNames
      final dir = new Directory.fromPath(p);
      safeThen(dir.exists(), connex, (exists) {
        if (exists)
          for (final nm in connex.server.indexNames) {
            file = new File.fromPath(p.append(nm));
            if (file.existsSync()) {
              loadFile(connex, file);
              return;
            }
          }
        throw new Http404(path);
      });
    });
  }
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
