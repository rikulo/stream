//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Jan 16, 2013  9:52:00 AM
// Author: tomyeh
part of stream_rspc;

class _Environ {
  Encoding encoding = utf8;
  bool verbose = false, lineNumber = false;
  List<String> sources;
}

/** The entry point of RSP compiler.
 */
void main(List<String> arguments) {
  final env = new _Environ();
  if (!_parseArgs(arguments, env))
    return;

  for (final String name in env.sources)
    compileFile(name, encoding: env.encoding, verbose: env.verbose,
        lineNumber: env.lineNumber);
}

bool _parseArgs(List<String> arguments, _Environ env) {
  final argParser = new ArgParser()
    ..addOption("encoding", abbr: 'e',
      help: "Specify character encoding used by source file, such as utf-8, ascii and latin-1")
    ..addFlag("help", abbr: 'h', negatable: false, help: "Display this message")
    ..addFlag("line-number", abbr: 'n', negatable: false, help: "Output the line number of the source file")
    ..addFlag("verbose", abbr: 'v', negatable: false, help: "Enable verbose output")
    ..addFlag("version", negatable: false, help: "Version information");
  final args = argParser.parse(arguments);

  final usage = "Usage: rspc [<flags>] <rsp-file> [<rsp-file>...]";
  if (args['version']) {
    print("RSP Compiler version $VERSION");
    return false;
  }
  if (args['help']) {
    print(usage);
    print("\nCompiles the RSP file to a Dart file.\n\nOptions:");
    print(argParser.usage);
    return false;
  }

  String val = args['encoding'];
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
    ..verbose = args['verbose']
    ..lineNumber = args['line-number']
    ..sources = args.rest;
  return true;
}
