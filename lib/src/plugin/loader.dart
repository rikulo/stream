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

  /** A map of content types. For example,
   *
   *     ContentType ctype = resouceLoader.contentTypes['js'];
   */
  final Map<String, ContentType> contentTypes;
  /** A list of names that will be used to locate the resource if
   * the given path is a directory.
   *
   * Default: `index.html` and `index.htm`
   */
  final List<String> indexNames;
  /** The root directory.
   */
  final Path rootDir;

  /** Test if the resource of the given path exists.
   */
  bool exists(String path);
  /** Loads the resource of the given path to the given response.
   */
  void load(HttpRequest request, HttpResponse response, String path);
}

/** A file-system-based resource loader.
 */
class FileLoader implements ResourceLoader {
  FileLoader(Path this.rootDir);

  @override
  final Path rootDir;

  //@override
  bool exists(String path) => _fileOf(path) != null;
  void load(HttpRequest req, HttpResponse res, String path) {
    final fl = _fileOf(path);
    if (fl == null)
      throw new FileIOException("Not found: $path");

    //TODO: handle headers
    final headers = res.headers;
    final ctype = contentTypes[new Path(fl.name).extension];
    if (ctype != null)
      headers.contentType = ctype;

    //write content
    final out = res.outputStream;
    final inp = fl.openInputStream();
    inp.pipe(out, close: true);
  }
  File _fileOf(String path) {
    if (path != null) {
      if (path.startsWith('/'))
        path = path.substring(1);
      if (path.startsWith("webapp/") || path == "webapp")
        return null; //protect webapp from access

      final p = rootDir.append(path);
      var fl = new File.fromPath(p);
      if (fl.existsSync())
        return fl;

      var dir = new Directory.fromPath(p);
      if (dir.existsSync())
        for (final nm in indexNames) {
          fl = new File.fromPath(p.append(nm));
          if (fl.existsSync())
            return fl;
        }
    }
    return null;
  }

  @override
  final List<String> indexNames = ['index.html', 'index.htm'];
  @override
  final Map<String, ContentType> contentTypes = {
    'aac': new ContentType.fromString('audio/aac'),
    'aiff': new ContentType.fromString('audio/aiff'),
    'css': new ContentType.fromString('text/css'),
    'csv': new ContentType.fromString('text/csv'),
    'doc': new ContentType.fromString('application/vnd.ms-word'),
    'docx': new ContentType.fromString('application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
    'gif': new ContentType.fromString('image/gif'),
    'htm': new ContentType.fromString('text/html'),
    'html': new ContentType.fromString('text/html'),
    'ico': new ContentType.fromString('image/x-icon'),
    'jpg': new ContentType.fromString('image/jpeg'),
    'jpeg': new ContentType.fromString('image/jpeg'),
'    js': new ContentType.fromString('text/javascript'),
    'mid': new ContentType.fromString('audio/mid'),
    'mp3': new ContentType.fromString('audio/mp3'),
    'mp4': new ContentType.fromString('audio/mp4'),
    'mpg': new ContentType.fromString('video/mpeg'),
    'mpeg': new ContentType.fromString('video/mpeg'),
    'mpp': new ContentType.fromString('application/vnd.ms-project'),
    'odf': new ContentType.fromString('application/vnd.oasis.opendocument.formula'),
    'odg': new ContentType.fromString('application/vnd.oasis.opendocument.graphics'),
    'odp': new ContentType.fromString('application/vnd.oasis.opendocument.presentation'),
    'ods': new ContentType.fromString('application/vnd.oasis.opendocument.spreadsheet'),
    'odt': new ContentType.fromString('application/vnd.oasis.opendocument.text'),
    'pdf': new ContentType.fromString('application/pdf'),
    'png': new ContentType.fromString('image/png'),
    'ppt': new ContentType.fromString('application/vnd.ms-powerpoint'),
    'pptx': new ContentType.fromString('application/vnd.openxmlformats-officedocument.presentationml.presentation'),
    'rar': new ContentType.fromString('application/x-rar-compressed'),
    'rtf': new ContentType.fromString('application/rtf'),
    'txt': new ContentType.fromString('text/plain'),
    'wav': new ContentType.fromString('audio/wav'),
    'xls': new ContentType.fromString('application/vnd.ms-excel'),
    'xlsx': new ContentType.fromString('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
    'xml': new ContentType.fromString('text/xml'),
    'zip': new ContentType.fromString('application/zip')
  };
}
