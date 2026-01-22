//Sample of Stream: Hello Templating
library hello_templating;

import "dart:async";
import "package:stream/stream.dart";
import "package:rikulo_commons/logging.dart";
import "package:logging/logging.dart" show Logger, Level;

part "classic.rsp.dart"; //generated from classic.rsp.html
part "sidebar.rsp.dart"; //generated from sidebar.rsp.html
part "home.rsp.dart"; //generated from home.rsp.html

final logger = Logger('test');

//URI mapping
var _mapping = {
  "/": home //generated from home.rsp.html
};

void main() {
  Logger.root.level = Level.INFO;
  logger.onRecord.listen(simpleLoggerHandler);

  StreamServer(uriMapping: _mapping).start();
}
