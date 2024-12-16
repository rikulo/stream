//Sample of Stream: Hello Templates
library features;

import "dart:io";
import "dart:async";
import "package:stream/stream.dart";
import "package:rikulo_commons/mirrors.dart" show ObjectUtil;

part "includerView.rsp.dart";
part "fragView.rsp.dart";
part "searchResult.rsp.dart";
part "forwarderView.rsp.dart";
part 'json.rsp.dart'; //auto-inject from test/features/json.rsp.html
part 'lastModified.rsp.dart'; //auto-inject from ../lastModified.rsp.html

/// A special error to be handled specially (recover it).
const recoverableError = -900;

void main() {
  StreamServer(
    uriMapping: _uriMapping, errorMapping: _errMapping, filterMapping: _filterMapping)
    .start(zoned: true);
}

//URI mapping
var _uriMapping = <String, dynamic> {
  "/forward": forward,
  "/forwardRsp": forwarderView, //generated from forwarderView.rsp.html
  "/include": includerView,  //generated from includerView.rsp.html
  "/search": search,
  "/(?<group>g[a-z]*p)/(?<matching>ma[a-z]*)": (HttpConnect connect) {
    connect.response
      ..headers.contentType = ContentType.text
      ..write("Group Matching: ${DefaultRouter.getNamedGroup(connect, 'group')} "
        "and ${DefaultRouter.getNamedGroup(connect, 'matching')}");
  },
  "/old-link(?<extra>.*)": "/new-link(extra)/more",
  "/new-link(?<option>.*)?": (HttpConnect connect) {
    connect.response
      ..headers.contentType = ContentType.text
      ..write("old-link forwarded to ${connect.request.uri}"
        "(option: ${DefaultRouter.getNamedGroup(connect, 'option')})");
  },
  "/500": (HttpConnect connect) {
    throw Exception("something wrong");
  },
  "/async-err": (HttpConnect connect) {
    Future(() {
      throw Exception("in async operation");
    });

    connect.response
      ..headers.contentType = ContentType.html
      ..write("<html><body><p>Check the server console if the server stays alive and log the error.</p></body></html>");
  },
  "/recoverable-error": (HttpConnect connect) {
    throw recoverableError;
  },
  "/log5": (HttpConnect connect) {
    connect.response
      ..headers.contentType = ContentType.text
      ..write("You see two logs shown on the console");
  },
  "/longop": (HttpConnect connect) {
    connect.response
      ..headers.contentType = ContentType.html
      ..write("<html><body><p>This is used to test if client aborts the connection</p>"
        "<p>Close the browser tab as soon as possible (in 10 secs)</p>");
    return Future.delayed(const Duration(seconds: 10), () {
      connect.response.write("<p>You shall close the browser tab before seeing this</p></body></html>");
    });
  },
  "/redirect": (HttpConnect connect) {
    connect.redirect(connect.request.uri.queryParameters["uri"]!);
  },
  "/quire": "https://quire.io",
  "/json": json,
  "ws:/ws-test(/.*)?": (WebSocket socket) {
    socket.listen((evt) {
      socket.add("Server received: $evt");
    });
    return socket.done;
  },
  "/lastModified": lastModified
};

//Error mapping
var _errMapping = <int, dynamic> {
  404: "/404.html",
  500: (HttpConnect connect) {
    connect.response
      ..headers.contentType = ContentType.html
      ..write("""
<html>
<head><title>500: ${connect.errorDetail?.error?.runtimeType}</title></head>
<body>
 <h1>500: ${connect.errorDetail?.error}</h1>
 <pre><code>${connect.errorDetail?.stackTrace}</code></pre>
</body>
</html>
        """);
  },
  recoverableError: (HttpConnect connect) {
    connect.errorDetail = null; //clear error
    connect.response
      ..headers.contentType = ContentType.text
      ..write("Recovered from an error");
  }
};

//Filtering
var _filterMapping = <String, RequestFilter> {
  "/log.*": (HttpConnect connect, Future chain(HttpConnect conn)) {
    connect.server.logger.info("Filter 1: ${connect.request.uri}");
    return chain(connect);
  },
  "/log[0-9]*": (HttpConnect connect, Future chain(HttpConnect conn)) {
    connect.server.logger.info("Filter 2: ${connect.request.uri}");
    return chain(connect);
  }
};

//Forward//
Future forward(HttpConnect connect)
  => connect.forward("/forwardee.html?first=1st&second=2nd");

//Search//
class Criteria {
  String text = "";
  DateTime? since;
  int? within;
  bool hasAttachment = false;
}
Future search(HttpConnect connect) {
  final criteria = ObjectUtil.inject(Criteria(),
      connect.request.uri.queryParameters, silent: true);
  return searchResult(connect, criteria: criteria); //generated from searchResult.rsp.html
}
