//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Jan 08, 2013 11:59:45 AM
// Author: tomyeh

library stream;

import "dart:io";
import 'package:args/args.dart' show Options;
import "package:logging/logging.dart" show Logger;

import "package:rikulo_commons/util.dart";
import "package:rikulo_commons/io.dart";

import "plugin.dart";

part "src/http.dart";
part "src/server.dart";

/** A general Stream error.
 */
class StreamError implements Error {
  final String message;

  StreamError(String this.message);
  String toString() => "StreamError($message)";
}
