//Sample of Stream: Hello Dynamic Contents
library hello_dynamic;

import "dart:convert" show json;
import "package:stream/stream.dart";
import "package:rikulo_commons/io.dart" show getContentType;

//URI mapping
var _mapping = {
  "/server-info": serverInfo,
};

void serverInfo(HttpConnect connect) {
  final info = {"name": "Rikulo Stream", "version": connect.server.version};
  connect.response
    ..headers.contentType = getContentType("json")
    ..write(json.encode(info));
}

void main() {
  StreamServer(uriMapping: _mapping).start();
}
