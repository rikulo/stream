//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Jan 16, 2013  9:52:00 AM
// Author: tomyeh
part of stream_rspc;

class _Environ {
  Encoding encoding = UTF8;
  bool verbose = false;
  List<String> sources;
}

/** The entry point of RSP compiler.
 */
void main() {
  final env = new _Environ();
  if (!_parseArgs(env))
    return;

  for (var name in env.sources)
    compileFile(name, encoding: env.encoding, verbose: env.verbose);
}

bool _parseArgs(_Environ env) {
  final argParser = new ArgParser()
    ..addOption("encoding", abbr: 'e',
      help: "Specify character encoding used by source file, such as utf-8, ascii and latin-1")
    ..addFlag("help", abbr: 'h', negatable: false, help: "Display this message")
    ..addFlag("verbose", abbr: 'v', negatable: false, help: "Enable verbose output")
    ..addFlag("version", negatable: false, help: "Version information");
  final args = argParser.parse(new Options().arguments);

  final usage = "Usage: rspc [<flags>] <rsp-file> [<rsp-file>...]";
  if (args['version']) {
    print("RSP Compiler version $VERSION");
    return false;
  }
  if (args['help']) {
    print(usage);
    print("\nCompiles the RSP file to a Dart file.\n\nOptions:");
    print(argParser.getUsage());
    return false;
  }

  String val = args['encoding'];
  if (val != null)
    switch (val.toLowerCase()) {
      case 'ascii':
        env.encoding = ASCII;
        break;
      case 'utf-8':
        env.encoding = UTF8;
        break;
      case 'iso-8859-1':
      case 'latin-1':
        env.encoding = LATIN1;
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

  env.verbose = args['verbose'];
  env.sources = args.rest;
  return true;
}
