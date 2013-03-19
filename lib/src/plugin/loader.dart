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
  FileLoader(this.rootDir);

  @override
  final Path rootDir;

  @override
  void load(HttpConnect connect, String uri) {
    var path = uri.substring(1); //must start with '/'
    path = rootDir.append(path);

    var file = new File.fromPath(path);
    file.exists().then((exists) {
      if (!exists)
        return new Directory.fromPath(path).exists();
      loadFile(connect, file);
      //return null;
    }).then((exists) {
      if (exists != null) //null means done
        if (exists)
          _loadFileAt(connect, uri, path, connect.server.indexNames, 0);
        else
          throw new Http404(uri);
    }).catchError(connect.error);
  }
}

bool _loadFileAt(HttpConnect connect, String uri, Path dir, List<String> names, int j) {
  if (j >= names.length)
    throw new Http404(uri);

  final file = new File.fromPath(dir.append(names[j]));
  file.exists().then((exists) {
    if (exists)
      loadFile(connect, file);
    else
      _loadFileAt(connect, uri, dir, names, j + 1);
  }).catchError(connect.error);
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
  final ctype = contentTypes[new Path(file.path).extension];
  if (ctype != null)
    headers.contentType = ctype;

  file.length().then((length) {
    connect.response.contentLength = length;
    return file.lastModified();
  }).then((date) {
    headers.add(HttpHeaders.LAST_MODIFIED, date);
    _loadFile(connect, file);
  }).catchError(connect.error);
}

void _loadFile(HttpConnect connect, File file) {
  final res = connect.response;
  file.openRead().listen((data) {res.writeBytes(data);},
    onDone: connect.close, onError: connect.error);
}
