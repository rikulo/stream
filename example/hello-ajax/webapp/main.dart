//Sample of Stream: Hello Dynamic Contents
library hello_dynamic;

import "dart:convert" show JSON;
import "package:stream/stream.dart";
import "package:rikulo_commons/io.dart" show contentTypes;

//URI mapping
var _mapping = {
  "/server-info": serverInfo,
};

void serverInfo(HttpConnect connect) {
  final info = {"name": "Rikulo Stream", "version": connect.server.version};
  connect.response
    ..headers.contentType = contentTypes["json"]
    ..write(JSON.encode(info));
}

void main() {
  new StreamServer(uriMapping: _mapping).start();
}
