//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Jan 16, 2013  9:52:00 AM
// Author: tomyeh
part of stream_rspc;

class _Environ {
  Encoding encoding = utf8;
  bool verbose = false, lineNumber = false, newer = false;
  late List<String> sources;
}

class _Stats {
  int nCompiled = 0;
  int nSkipped = 0;

  void onCompile(String source, {bool skipped = false}) {
    if (skipped) {
      print("$source not modified");
      ++nSkipped;
    } else {
      ++nCompiled;
    }
  }
  void printSummary() {
    if (nCompiled + nSkipped > 1) { //don't print if single file
      if (nCompiled > 0)
        print("$nCompiled files are compiled");
      if (nSkipped > 0)
        print("$nSkipped files are not modified");
    }
  }
}

/** The entry point of RSP compiler.
 */
Future main(List<String> arguments) async {
  final env = new _Environ();
  if (!_parseArgs(arguments, env))
    return;

  final stats = new _Stats();

  Future compile(String name)
  => compileFile(name, encoding: env.encoding, verbose: env.verbose,
          lineNumber: env.lineNumber, newer: env.newer,
          onCompile: stats.onCompile);

  for (final String name in env.sources) {
    final dir = new Directory(name);
    if (await dir.exists()) {
      await for (final fse in dir.list(recursive: true)) {
        final path = fse.path;
        if (path.endsWith(".rsp.html")
        && await FileSystemEntity.isFile(path)) {
          try {
            await compile(path);
          } catch (ex, st) {
            print("Unable to compile $path: $ex\n$st");
          }
        }
      }
    } else {
      compile(name);
    }
  }

  stats.printSummary();
}

bool _parseArgs(List<String> arguments, _Environ env) {
  final argParser = new ArgParser()
    ..addOption("encoding", abbr: 'e',
      help: "Specify character encoding used by source file, such as utf-8, ascii and latin-1. Default: utf-8.")
    ..addFlag("newer", abbr: 'n', negatable: true, help: "Compile only if source file is newer. Default: false.")
    ..addFlag("help", abbr: 'h', negatable: false, help: "Display this message")
    ..addFlag("line-number", abbr: 'l', negatable: false, help: "Output the line number of the source file. Default: false.")
    ..addFlag("verbose", abbr: 'v', negatable: false, help: "Enable verbose output. Default: false.")
    ..addFlag("version", negatable: false, help: "Version information");
  final args = argParser.parse(arguments);

  final usage = "Usage: rspc [<flags>] <dir-or-rsp-file> [<dir-or-rsp-file>...]";
  if (args['version'] as bool) {
    print("RSP Compiler version $version");
    return false;
  }
  if (args['help'] as bool) {
    print(usage);
    print("\nCompiles the RSP file to a Dart file.\n\nOptions:");
    print(argParser.usage);
    return false;
  }

  var val = args['encoding'] as String?;
  if (val != null)
    switch (val.toLowerCase()) {
      case 'ascii':
        env.encoding = ascii;
        break;
      case 'utf-8':
        env.encoding = utf8;
        break;
      case 'iso-8859-1':
      case 'latin-1':
        env.encoding = latin1;
        break;
      default:
        print("Unknown encoding: $val");
        return false;
    }

  if (args.rest.isEmpty) {
    print(usage);
    print("Use -h for a list of possible options.");
    return false;
  }

  env
    ..newer = args['newer'] as bool
    ..verbose = args['verbose'] as bool
    ..lineNumber = args['line-number'] as bool
    ..sources = args.rest;
  return true;
}
