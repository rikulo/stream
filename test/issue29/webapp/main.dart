//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Sun, May 19, 2013  1:51:09 PM
// Author: tomyeh

import "package:stream/stream.dart";
import "package:rikulo_commons/logging.dart";
import "package:logging/logging.dart" show Logger, Level;

final logger = Logger('test');

void main() {
  Logger.root.level = Level.INFO;
  logger.onRecord.listen(simpleLoggerHandler);

  StreamServer(homeDir: "static").start();
}
