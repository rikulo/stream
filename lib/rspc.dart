//RSP　（Rikulo Stream Page） Compiler
//
//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Mon, Jan 14, 2013  2:08:32 PM
// Author: tomyeh
library stream_rspc;

import 'dart:io' show Encoding;
import 'package:args/args.dart';

import "rsp.dart" show compileFile;

const VERSION = "0.5.0";

class _Environ {
  Encoding encoding = Encoding.UTF_8;
  bool verbose = false;
  bool fragment; //null means auto
  List<String> sources;
}

/** The entry point of RSP compiler.
 */
void main() {
  final env = new _Environ();
  if (!_parseArgs(env))
    return;

  for (var name in env.sources) {
    bool fragment = env.fragment;
    if (fragment == null)
      fragment = name.indexOf(".rsf") >= 0;
    compileFile(name, encoding: env.encoding, verbose: env.verbose, fragment: fragment);
  }
}

bool _parseArgs(_Environ env) {
  final argParser = new ArgParser()
    ..addOption("fragment", abbr: 'f', help:
      "Specify whether the given file is a fragment of HTML."
      " If not specified, it is based on the extension (.rsf for fragment).")
    ..addOption("encoding", abbr: 'e', help: "Specify character encoding used by source file")
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
        env.encoding = Encoding.ASCII;
        break;
      case 'utf-8':
        env.encoding = Encoding.UTF_8;
        break;
      case 'iso-8859-1':
        env.encoding = Encoding.ISO_8859_1;
        break;
      default:
        print("Unknown encoding: $val");
        return false;
    }
  val = args['fragment'];
  if (val != null)
    env.fragment = val == "true";

  if (args.rest.isEmpty) {
    print(usage);
    print("Use -h for a list of possible options.");
    return false;
  }

  env.verbose = args['verbose'];
  env.sources = args.rest;
  return true;
}
