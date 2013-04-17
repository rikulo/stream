//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Mon, Jan 14, 2013  4:33:10 PM
// Author: tomyeh
part of stream_rspc;

/** Compiles the given [source] RSP document to the given output stream [out].
 * Notice that the caller has to close the output stream by himself.
 */
void compile(String source, IOSink out, {String sourceName, String destinationName,
    Encoding encoding: Encoding.UTF_8, bool verbose: false}) {
  new Compiler(source, out, sourceName: sourceName, destinationName: destinationName,
      encoding: encoding, verbose: verbose).compile();
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

  File dest;
  if (destinationName == null) {
    final int i = sourceName.lastIndexOf('.');
    final int j = sourceName.lastIndexOf('/');
    destinationName = i >= 0 && j < i ? "${sourceName.substring(0, i + 1)}dart" : "${sourceName}.dart";
    dest = _locate(destinationName);
  } else {
    dest = new File(destinationName);
    _createFileDirectoryIfNecessary(destinationName);
  }

  if (FileSystemEntity.identicalSync(source.path, dest.path)) {
    print("Source and destination are the same file, $source");
    return;
  }

  if (verbose) {
    final int i = dest.path.lastIndexOf('/') + 1;
    print("Compile ${source.path} to ${i > 0 ? dest.path.substring(i) : dest.path}");
  }
  
  source.readAsString(encoding: encoding).then((text) {
    final out = dest.openWrite(encoding: encoding);
    try {
      compile(text, out, sourceName: sourceName,
          destinationName: new Path(dest.path).toString(), //force to use '/' even in Windows
          encoding: encoding, verbose: verbose);
    } on SyntaxError catch (e) {
      print("${e.message}\nCompilation aborted.");
    } finally {
      out.close();
    }
  });
}

/// This method is necessary since File.directorySync() throws exception if parent directory does not exist
/// TODO: change this method when bug 9926 is fixed
void _createFileDirectoryIfNecessary( String destinationName ) {
  var path = destinationName;
  var i = path.lastIndexOf("/");
  path = path.substring(0, i);
  new Directory(path).create(recursive:true);
}

///Locates the right location under the webapp folder, if there is one
File _locate(String flnm) {
  final List<String> segs = [];
  Path path = new Path(flnm).canonicalize();
  if (!path.isAbsolute)
    path = new Path(new Directory.current().path).join(path);

  for (;;) {
    segs.add(path.filename);
    path = path.directoryPath;
    if (path.isEmpty || path.toString() == "/")
      break;

    final dir = new Directory.fromPath(path);
    if (dir.existsSync()) {
      if (path.filename == "webapp"
      || new File.fromPath(new Path(dir.path).append("pubspec.yaml")).existsSync())
        break; //under webapp, or no webapp at all (since project found)
      if (new Directory.fromPath(new Path(dir.path).append("webapp")).existsSync()) {
        segs.add("webapp"); //not under webapp
        break;
      }
    }
  }

  for (int i = segs.length; --i > 0;)
    path = path.append(segs[i]);
  final dir = new Directory.fromPath(path);
  if (!dir.existsSync())
    dir.create(recursive: true);
  path = path.relativeTo(new Path(new Directory.current().path));
  return new File.fromPath(path.append(segs[0]));
}

/**
 * A typedef for functions that receive a project relative file path and map
 * it to its final destination. It is used by RSP compiler to decide where
 * to generate its .rsp.dart files.
 * 
 * This type of functions receive the file name in [projectRelativePath] and
 * must return a modified version of it ending with the same extension. Then
 * that extension is changed by the compiler to .dart.
 */
typedef String FileNameMapper( String projectRelativeFilePath );

/** 
 * Compile changed RSP files. This method shall be called within build.dart,
 * with new Options().arguments as its [arguments].
 *
 * Optionally, you can provide a [FileNameMapper] function as a named argument
 * [fileMapper] to be able to alter the location where rsp compiled files are
 * written.
 *
 * Notice that it accepts files ending with `.rsp.whatever`.
 */
void build(List<String> arguments, {FileNameMapper fileMapper}) {
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
          compileFile(fse.path,destinationName:_mapFileName(fse.path,fileMapper));
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
          compileFile(name,destinationName:_mapFileName(name,fileMapper));
    }
  }
}

String _mapFileName(String name,FileNameMapper fileMapper) {
  if( fileMapper!=null ) {
    name = _convertToProjectPath(name);
    name = fileMapper(name);
    name = _convertRspSourceExtension(name);
    return name;
  }
}

String _convertRspSourceExtension( String path ) {
  var i = path.lastIndexOf(".");
  return path.substring(0,i)+".dart";
}

String __projectDir;
String get _projectDir {
  if( __projectDir==null ) {
    __projectDir = new Directory.current().path; 
  }
  return __projectDir;
}

String _convertToProjectPath( String path ) {
  if( path.startsWith( _projectDir ) ) {
    path = path.substring( _projectDir.length+1 );
  }
  return path;
}

int _rspSource(String name) {
  if (!name.endsWith(".rsp.dart")) {
    var i = name.indexOf(".rsp.");
    if (i >= 0 && name.indexOf('/', i += 5) < 0 && name.indexOf('.', i) < 0)
      return i;
  }
  return -1;
}
