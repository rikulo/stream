//Sample of Stream: Hello Dynamic Contents
library hello_dynamic;

import "dart:json" show JSON;
import "package:stream/stream.dart";

part "config.dart";

void serverInfo(HttpConnect connect) {
  final info = {"name": "Rikulo Stream", "version": connect.server.version};
  connect.response.headers.contentType = contentTypes["json"];
  connect.response.outputStream
    ..writeString(JSON.stringify(info))..close();
}

void main() {
  new StreamServer(uriMapping: _mapping).run();
}
