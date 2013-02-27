//Sample of Stream: Hello Templates
library hello_template;

import "dart:io";
import "package:stream/stream.dart";

part "config.dart";
part "helloView.rsp.dart"; //generated from helloView.rsp.html

void main() {
  new StreamServer(uriMapping: _mapping).start();
}
