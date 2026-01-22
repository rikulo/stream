//Sample of Stream: Hello Static Resources
library hello_static;

import "package:stream/stream.dart";
import "package:rikulo_commons/logging.dart";
import "package:logging/logging.dart" show Logger, Level;

final logger = Logger('test');

void main() {
  Logger.root.level = Level.INFO;
  logger.onRecord.listen(simpleLoggerHandler);

  StreamServer().start();
}
