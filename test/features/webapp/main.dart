//Sample of Stream: Hello Templates
library features;

import "dart:io";
import "dart:async";
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
Future forward(HttpConnect connect)
	=> connect.forward("/forwardee.html?first=1st&second=2nd");

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
Future search(HttpConnect connect) {
  return ObjectUtil.inject(new Criteria(), connect.request.queryParameters, silent: true)
    .then((criteria) {
      return searchResult(connect, criteria: criteria); //generated from searchResult.rsp.html
    });
}
