//Sample of Stream: Hello Dynamic Contents
library hello_dynamic;

import "package:stream/stream.dart";

part "config.dart";

void serverInfo(HttpConnex connex) {
  
}
void main() {
  new StreamServer(uriMapping: _mapping).run();
}
