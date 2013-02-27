//Sample of Stream: Hello Dynamic Contents
library hello_dynamic;

import "dart:json" as Json;
import "package:stream/stream.dart";

part "config.dart";

void serverInfo(HttpConnect connect) {
  final info = {"name": "Rikulo Stream", "version": connect.server.version};
  connect.response
    ..headers.contentType = contentTypes["json"]
    ..addString(Json.stringify(info));
  connect.close();
}

void main() {
  new StreamServer(uriMapping: _mapping).start();
}
