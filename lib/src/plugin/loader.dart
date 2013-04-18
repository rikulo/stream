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
  Future load(HttpConnect connect, String uri);
}

/** A file-system-based resource loader.
 */
class FileLoader implements ResourceLoader {
  FileLoader(this.rootDir);

  @override
  final Path rootDir;

  @override
  Future load(HttpConnect connect, String uri) {
    var path = uri.substring(1); //must start with '/'
    path = rootDir.append(path);

    var file = new File.fromPath(path);
    return file.exists().then((exists) {
      if (!exists)
        return new Directory.fromPath(path).exists();
      return loadFile(connect, file);
    }).then((exists) {
      if (exists is bool) { //null or other value means done (i.e., returned by loadFile)
        if (exists)
          return _loadFileAt(connect, uri, path, connect.server.indexNames, 0);
        throw new Http404(uri);
      }
    });
  }
}

Future _loadFileAt(HttpConnect connect, String uri, Path dir, List<String> names, int j) {
  if (j >= names.length)
    throw new Http404(uri);

  final file = new File.fromPath(dir.append(names[j]));
  return file.exists().then((exists) {
    return exists ? loadFile(connect, file):
      _loadFileAt(connect, uri, dir, names, j + 1);
  });
}

/** Loads a file into the given response.
 * Notice that this method assumes the file exists.
 */
Future loadFile(HttpConnect connect, File file) {
  if (connect.isIncluded)
    return _loadFile(connect, file);

  final headers = connect.response.headers;
  final ctype = contentTypes[new Path(file.path).extension];
  if (ctype != null)
    headers.contentType = ctype;

  return file.length().then((length) {
    connect.response.contentLength = length;
    return file.lastModified();
  }).then((date) {
    headers.add(HttpHeaders.LAST_MODIFIED, date);
    return _loadFile(connect, file);
  });
}

Future _loadFile(HttpConnect connect, File file)
=> connect.response.addStream(file.openRead()); //returns Future<HttpResponse>
