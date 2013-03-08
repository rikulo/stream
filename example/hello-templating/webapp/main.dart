//Sample of Stream: Hello Templating
library hello_templating;

import "dart:io";
import "package:stream/stream.dart";

part "config.dart";
part "classic.rsp.dart"; //generated from classic.rsp.html
part "sidebar.rsp.dart"; //generated from sidebar.rsp.html
part "home.rsp.dart"; //generated from home.rsp.html

void main() {
  new StreamServer(uriMapping: _mapping).start();
}
