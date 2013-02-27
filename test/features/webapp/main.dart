//Sample of Stream: Hello Templates
library features;

import "dart:io";
import "package:stream/stream.dart";
import "package:rikulo_commons/mirrors.dart" show ObjectUtil;

part "config.dart";
part "includerView.rsp.dart";
part "fragView.rsp.dart";
part "searchResult.rsp.dart";

void main() {
  new StreamServer(
    uriMapping: _uriMapping, errorMapping: _errMapping, filterMapping: _filterMapping)
    .start();
}

//Forward//
String forward(HttpConnect connect) => "/forwardee.html";

//Recover from an error//
class RecoverError {
}

//Search//
class Criteria {
  String text = "";
  DateTime since;
  int within;
  bool hasAttachment = false;
}
void search(HttpConnect connect) {
  ObjectUtil.inject(new Criteria(), connect.request.queryParameters, silent: true)
    .then((criteria) {
      searchResult(connect, criteria: criteria); //generated from searchResult.rsp.html
    });
}
