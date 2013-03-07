//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Mon, Jan 14, 2013  4:33:10 PM
// Author: tomyeh
part of stream_rspc;

/** Compiles the given [source] RSP document to the given output stream [out].
 * Notice that the caller has to close the output stream by himself.
 */
void compile(String source, IOSink out, {
String sourceName, Encoding encoding: Encoding.UTF_8, bool verbose: false}) {
  new Compiler(source, out, sourceName: sourceName, encoding: encoding, verbose: verbose)
    .compile();
}

/** Compiles the RSP document of the given [sourceName] and write the result to
 * the file of given [destinationName].
 */
void compileFile(String sourceName, {String destinationName, bool verbose : false, 
Encoding encoding : Encoding.UTF_8}) {
  final source = new File(sourceName);
  if (!source.existsSync()) {
    print("File not found: ${sourceName}");
    return;
  }
  
  if (destinationName == null) {
    final int i = sourceName.lastIndexOf('.');
    final int j = sourceName.lastIndexOf('/');
    destinationName = i >= 0 && j < i ? "${sourceName.substring(0, i + 1)}dart" : "${sourceName}.dart";
  }
  final dest = new File(destinationName);
  
  if (verbose) {
    final int i = dest.path.lastIndexOf('/') + 1;
    print("Compile ${source.path} to ${i > 0 ? dest.path.substring(i) : dest.path}");
  }
  
  source.readAsString(encoding).then((text) {
    final out = dest.openWrite();
    try {
      compile(text, out, sourceName: sourceName, encoding: encoding, verbose: verbose);
    } on SyntaxError catch (e) {
      print("${e.message}\nCompilation aborted.");
    } finally {
      out.close();
    }
  });
}

/** Compile changed RSP files. This method shall be called within build.dart,
 * with new Options().arguments as its [arguments].
 *
 * Notice that it accepts files ending with `.rsp.whatever`.
 */
void build(List<String> arguments) {
  final ArgParser argParser = new ArgParser()
    ..addOption("changed", allowMultiple: true)
    ..addOption("removed", allowMultiple: true)
    ..addFlag("clean", negatable: false)
    ..addFlag("machine", negatable: false)
    ..addFlag("full", negatable: false);

  final ArgResults args = argParser.parse(arguments);
  final List<String> changed = args["changed"];
  final List<String> removed = args["removed"];
  final bool clean = args["clean"];
  
  if (clean) { // clean only
    new Directory.current().list(recursive: true).listen((fse) {
      if (fse is File && fse.path.endsWith(".rsp.dart"))
        fse.delete();
    });

  } else if (removed.isEmpty && changed.isEmpty) { // full build
    new Directory.current().list(recursive: true).listen((fse) {
      if (fse is File && _rspSource(fse.path) >= 0)
          compileFile(fse.path);
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
          compileFile(name);
    }
  }
}
int _rspSource(String name) {
  if (!name.endsWith(".rsp.dart")) {
    var i = name.indexOf(".rsp.");
    if (i >= 0 && name.indexOf('/', i += 5) < 0 && name.indexOf('.', i) < 0)
      return i;
  }
  return -1;
}
