//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Mon, Jan 14, 2013  4:33:10 PM
// Author: tomyeh
part of stream_rspc;

/** Compiles the given [source] RSP document to the given output stream [out].
 * Notice that the caller has to close the output stream by himself.
 *
 * * [imports] - additional imported packages, such as `["package:foo/foo.dart"]`.
 */
void compile(String source, IOSink out, {String sourceName, String destinationName,
    Encoding encoding: utf8, bool verbose: false, bool lineNumber: false,
    List<String> imports}) {
  new Compiler(source, out, sourceName: sourceName, destinationName: destinationName,
      encoding: encoding, verbose: verbose, lineNumber: lineNumber, imports: imports)
  .compile();
}

/** Compiles the RSP document of the given [sourceName] and write the result to
 * the file of given [destinationName].
 * 
 * It returns true if the file has been compiled.
 *
 * * [newer] - If true, it compiles only if the source file is newer or
 * the destination file doesn't exist.
 * * [imports] - additional imported packages, such as `["package:foo/foo.dart"]`.
 * * [onCompile] - Optional. If specified, it is called when compiling a file,
 * or when skipping the compilation because of not-modified
 */
Future<bool> compileFile(String sourceName, {String destinationName,
    bool verbose: false, bool newer: false,
    bool lineNumber: false, Encoding encoding: utf8, List<String> imports,
    void onCompile(String source, {bool/*!*/ skipped})}) async {
  final source = new File(sourceName);
  if (!await source.exists()) {
    print("File not found: ${sourceName}");
    return false;
  }

  File dest;
  if (destinationName == null) {
    final int i = sourceName.lastIndexOf('.');
    final int j = sourceName.lastIndexOf('/');
    destinationName = i >= 0 && j < i ? "${sourceName.substring(0, i + 1)}dart" : "${sourceName}.dart";
    dest = await _locate(destinationName);
  } else {
    dest = new File(destinationName);
  }

  if (newer) {
    try {
      if ((await source.lastModified()).isBefore(await dest.lastModified())) {
        onCompile?.call(sourceName, skipped: true);
        return false;
      }
    } catch (_) {
      //ignore
    }
  }

  if (Path.normalize(source.path) == Path.normalize(dest.path)) {
    print("Source and destination are the same file, $source");
    return false;
  }

  if (verbose) {
    final int i = dest.path.lastIndexOf('/') + 1;
    print("Compile ${source.path} to ${i > 0 ? dest.path.substring(i) : dest.path}");
  }

  final text = await source.readAsString(encoding: encoding);
  final out = dest.openWrite(encoding: encoding);
  try {
    onCompile?.call(sourceName, skipped: false);
    compile(text, out, sourceName: sourceName,
        destinationName: _unipath(dest.path), //force to use '/' even in Windows
        encoding: encoding, verbose: verbose, lineNumber: lineNumber,
        imports: imports);
    return true;
  } on SyntaxError catch (e) {
    print("${e.message}\nCompilation aborted.");
    return false;
  } finally {
    out.close();
  }
}

///Locates the right location under the webapp folder, if there is one
Future<File> _locate(String flnm) async {
  final List<String> segs = [];
  String path = Path.absolute(Path.normalize(flnm));
  for (;;) {
    segs.add(Path.basename(path));
    path = Path.dirname(path);
    if (path.isEmpty || path == Path.separator)
      break;

    final dir = new Directory(path);
    if (await dir.exists()) {
      if (Path.basename(path) == "webapp"
      || await new File(Path.join(dir.path, "pubspec.yaml")).exists())
        break; //under webapp, or no webapp at all (since project found)
      if (await new Directory(Path.join(dir.path, "webapp")).exists()) {
        segs.add("webapp"); //not under webapp
        break;
      }
    }
  }

  for (int i = segs.length; --i > 0;)
    path = Path.join(path, segs[i]);
  final dir = new Directory(path);
  if (!await dir.exists())
    dir.create(recursive: true);
  path = Path.relative(path);
  return new File(Path.join(path, segs[0]));
}

/** Compile changed RSP files. This method shall be called within build.dart,
 * with the arguments passed to `main()` as its [arguments].
 *
 * Notice that it accepts files ending with `.rsp.whatever`.
 *
 * * [filenameMapper] - returns the filename of the destination file, which
 * must end with `.dart`. If omitted, it will be generated under the `webapp`
 * folder with the same path structure.
 * * [imports] - additional imported packages, such as `["package:foo/foo.dart"]`.
 */
Future build(List<String> arguments, {String filenameMapper(String source),
    Encoding encoding: utf8, List<String> imports}) async {
  final ArgParser argParser = new ArgParser()
    ..addMultiOption("changed")
    ..addMultiOption("removed")
    ..addFlag("clean", negatable: false)
    ..addFlag("machine", negatable: false)
    ..addFlag("full", negatable: false);

  final args = argParser.parse(arguments);
  final changed = args["changed"] as List<String>;
  final removed = args["removed"] as List<String>;
  final clean = args["clean"] as bool;
  
  if (clean) { // clean only
    Directory.current.list(recursive: true).listen((fse) {
      if (fse is File && fse.path.endsWith(".rsp.dart"))
        fse.delete();
    });

  } else if (removed.isEmpty && changed.isEmpty) { // full build
    Directory.current.list(recursive: true).listen((fse) {
      if (fse is File && _rspSource(fse.path) >= 0)
        compileFile(fse.path, encoding: encoding,
          destinationName: filenameMapper != null ? filenameMapper(fse.path): null,
          imports: imports);
    });

  } else {
    for (String name in removed) {
      final i = _rspSource(name);
      if (i >= 0) {
        final File gen = new File("${name.substring(0, i)}dart");
        if (await gen.exists())
          gen.delete();
      }
    }

    for (String name in changed) {
      if (_rspSource(name) >= 0)
        compileFile(name, encoding: encoding,
          destinationName: filenameMapper != null ? filenameMapper(name): null,
          imports: imports);
    }
  }
}
int _rspSource(String name) {
  if (!name.endsWith(".rsp.dart")) {
    int i = name.indexOf(".rsp.");
    if (i >= 0 && name.indexOf('/', i += 5) < 0 && name.indexOf('.', i) < 0)
      return i;
  }
  return -1;
}
