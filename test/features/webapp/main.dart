//Sample of Stream: Hello Templates
library features;

import "dart:io";
import "package:stream/stream.dart";

part "config.dart";
part "includerView.rsp.dart";
part "fragView.rsp.dart";

void main() {
  new StreamServer(
    uriMapping: _uriMapping, errorMapping: _errMapping, filterMapping: _filterMapping)
    .run();
}

//Controllers//
String forward(HttpConnect connect) => "/forwardee.html";

//Utilities//
class RecoverError {
}