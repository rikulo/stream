//Sample of Stream: Hello RSP
library hello_rsp;

import "dart:io";
import "package:stream/stream.dart";

part "config.dart";
part "helloView.rsp.dart"; //generated from helloView.rsp.html

void main() {
  new StreamServer(uriMapping: _mapping).start();
}
