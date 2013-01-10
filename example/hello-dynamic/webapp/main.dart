//Sample of Stream: Hello Dynamic Resources
library hello_dynamic;

import "package:stream/stream.dart";

part "config.dart";

///HelloWorld controller.
void helloworld(StreamRequest request, StreamResponse response) {
  request.models["message"] = "Welcome to Rikulo Stream";
}

void main() {
  new StreamServer(urlMapping: _mapping).run();
}
