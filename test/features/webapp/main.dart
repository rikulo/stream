//Sample of Stream: Hello Templates
library features;

import "dart:io";
import "package:stream/stream.dart";

part "config.dart";
part "includerView.rsp.dart";
part "fragView.rsp.dart";

void main() {
  new StreamServer(uriMapping: _mapping).run();
}

//Controllers//
String forward(HttpConnect connect) => "/forwardee.html";
