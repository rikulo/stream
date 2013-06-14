//Sample of Stream: Hello RSP
library hello_rsp;

import "dart:async";
import "dart:io";
import "package:stream/stream.dart";

part "helloView.rsp.dart"; //generated from helloView.rsp.html

//URI mapping
var _mapping = {
  "/": helloView //generated from helloView.rsp.html
};

void main() {
  new StreamServer(uriMapping: _mapping).start();
}
