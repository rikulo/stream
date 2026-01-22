//Sample of Stream: Hello RSP
library hello_rsp;

import "dart:async";
import "package:stream/stream.dart";
import "package:rikulo_commons/logging.dart";
import "package:logging/logging.dart" show Logger, Level;

part "helloView.rsp.dart"; //generated from helloView.rsp.html

final logger = Logger('example');

//URI mapping
var _mapping = {
  "/": helloView //generated from helloView.rsp.html
};

void main() {
  Logger.root.level = Level.INFO;
  logger.onRecord.listen(simpleLoggerHandler);

  StreamServer(uriMapping: _mapping).start();
}
