//RSP　（Rikulo Stream Page） Compiler
//
//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Mon, Jan 14, 2013  2:08:32 PM
// Author: tomyeh
library stream_rspc;

import "dart:io";
import "dart:collection" show HashMap;
import "package:args/args.dart";
import "package:rikulo_commons/util.dart";

import "stream.dart" show contentTypes;

part "src/rspc/main.dart";
part "src/rspc/build.dart";
part "src/rspc/compiler.dart";
part "src/rspc/tag.dart";
part "src/rspc/tagutil.dart";

const VERSION = "0.5.5";
