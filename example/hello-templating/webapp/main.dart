//Sample of Stream: Hello Templating
library hello_templating;

import "dart:async";
import "package:stream/stream.dart";

part "classic.rsp.dart"; //generated from classic.rsp.html
part "sidebar.rsp.dart"; //generated from sidebar.rsp.html
part "home.rsp.dart"; //generated from home.rsp.html

//URI mapping
var _mapping = {
  "/": home //generated from home.rsp.html
};

void main() {
  StreamServer(uriMapping: _mapping).start();
}
