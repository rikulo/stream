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
    Encoding encoding: UTF8, bool verbose: false, bool lineNumber: false,
    List<String> imports}) {
  new Compiler(source, out, sourceName: sourceName, destinationName: destinationName,
      encoding: encoding, verbose: verbose, lineNumber: lineNumber, imports: imports)
  .compile();
}

/** Compiles the RSP document of the given [sourceName] and write the result to
 * the file of given [destinationName].
 *
 * * [imports] - additional imported packages, such as `["package:foo/foo.dart"]`.
 */
void compileFile(String sourceName, {String destinationName, bool verbose: false, 
    bool lineNumber: false, Encoding encoding: UTF8, List<String> imports}) {
  final source = new File(sourceName);
  if (!source.existsSync()) {
    print("File not found: ${sourceName}");
    return;
  }

  File dest;
  if (destinationName == null) {
    final int i = sourceName.lastIndexOf('.');
    final int j = sourceName.lastIndexOf('/');
    destinationName = i >= 0 && j < i ? "${sourceName.substring(0, i + 1)}dart" : "${sourceName}.dart";
    dest = _locate(destinationName);
  } else {
    dest = new File(destinationName);
  }

  if (Path.normalize(source.path) == Path.normalize(dest.path)) {
    print("Source and destination are the same file, $source");
    return;
  }

  if (verbose) {
    final int i = dest.path.lastIndexOf('/') + 1;
    print("Compile ${source.path} to ${i > 0 ? dest.path.substring(i) : dest.path}");
  }
  
  source.readAsString(encoding: encoding).then((String text) {
    final out = dest.openWrite(encoding: encoding);
    try {
      compile(text, out, sourceName: sourceName,
          destinationName: _unipath(dest.path), //force to use '/' even in Windows
          encoding: encoding, verbose: verbose, lineNumber: lineNumber,
          imports: imports);
    } on SyntaxError catch (e) {
      print("${e.message}\nCompilation aborted.");
    } finally {
      out.close();
    }
  });
}

///Locates the right location under the webapp folder, if there is one
File _locate(String flnm) {
  final List<String> segs = [];
  String path = Path.absolute(Path.normalize(flnm));

  for (;;) {
    segs.add(Path.basename(path));
    path = Path.dirname(path);
    if (path.isEmpty || path == Path.separator)
      break;

    final dir = new Directory(path);
    if (dir.existsSync()) {
      if (Path.basename(path) == "webapp"
      || new File(Path.join(dir.path, "pubspec.yaml")).existsSync())
        break; //under webapp, or no webapp at all (since project found)
      if (new Directory(Path.join(dir.path, "webapp")).existsSync()) {
        segs.add("webapp"); //not under webapp
        break;
      }
    }
  }

  for (int i = segs.length; --i > 0;)
    path = Path.join(path, segs[i]);
  final dir = new Directory(path);
  if (!dir.existsSync())
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
void build(List<String> arguments, {String filenameMapper(String source),
    Encoding encoding: UTF8, List<String> imports}) {
  final ArgParser argParser = new ArgParser()
    ..addMultiOption("changed")
    ..addMultiOption("removed")
    ..addFlag("clean", negatable: false)
    ..addFlag("machine", negatable: false)
    ..addFlag("full", negatable: false);

  final ArgResults args = argParser.parse(arguments);
  final List<String> changed = args["changed"];
  final List<String> removed = args["removed"];
  final bool clean = args["clean"];
  
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
        if (gen.existsSync())
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
