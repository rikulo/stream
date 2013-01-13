//Sample of Stream: Hello Dynamic Contents
library hello_dynamic;

import "dart:json" show JSON;
import "package:stream/stream.dart";

part "config.dart";

void serverInfo(HttpConnex connex) {
  final info = {"name": "Rikulo Stream", "version": connex.server.version};
  connex.response.headers.contentType = contentTypes["json"];
  connex.response.outputStream
    ..writeString(JSON.stringify(info))..close();
}

void main() {
  new StreamServer(uriMapping: _mapping).run();
}
