//Sample of Stream: Hello Templates
library hello_template;

import "package:stream/stream.dart";

part "config.dart";

void main() {
  new StreamServer(urlMapping: _mapping).run();
}
