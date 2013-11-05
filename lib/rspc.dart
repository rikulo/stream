//RSP　（Rikulo Stream Page） Compiler
//
//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Mon, Jan 14, 2013  2:08:32 PM
// Author: tomyeh
library stream_rspc;

import "dart:io";
import "dart:convert";
import "dart:collection" show HashMap, LinkedHashMap, LinkedHashSet;
import "dart:math" show Random;
import "package:args/args.dart";
import 'package:path/path.dart' as Path;
import "package:rikulo_commons/util.dart";
import "package:rikulo_commons/io.dart" show contentTypes;

import "stream.dart" show contentTypes;

part "src/rspc/main.dart";
part "src/rspc/build.dart";
part "src/rspc/compiler.dart";
part "src/rspc/tag.dart";
part "src/rspc/tag_util.dart";

const VERSION = "0.8.7";
