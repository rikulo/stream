//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Jan 08, 2013 11:59:45 AM
// Author: tomyeh

library stream;

import "dart:io";
import "dart:async";
import "dart:collection" show HashMap, LinkedHashMap;
import "dart:uri";
import 'package:meta/meta.dart';
import 'package:args/args.dart' show Options;
import "package:logging/logging.dart" show Logger;

import "package:rikulo_commons/util.dart";
import "package:rikulo_commons/io.dart";
import "package:rikulo_commons/async.dart";

import "plugin.dart";

part "src/connect.dart";
part "src/server.dart";
part "src/connect_impl.dart";
part "src/server_impl.dart";

/** Converts the given value to a non-null string.
 * If the given value is not null, `toString` is called.
 * If null, an empty string is returned.
 *
 * > It is used in the generated code of RSP pages.
 */
String $nns([v]) => v != null ? v.toString(): "";

/** Converts the given value to a non-null [Future].
 *
 * > It is used in the generated code of RSP pages.
 */
Future $nnf([v]) => v is Future ? v: new Future.value(v);

/** Concatenates a path with a map of parameters.
 *
 * > It is used in the generated code of RSP pages.
 */
String $catUri(String uri, Map<String, dynamic> parameters) {
  if (parameters == null || parameters.isEmpty)
    return uri;

  int i = uri.indexOf('?');
  String query;
  if (i >= 0) {
    query = uri.substring(i);
    uri = uri.substring(0, i);
  }
  final query2 = HttpUtil.encodeQuery(parameters);
  return uri + (query == null ? "?query2": "$query&query2");
}
