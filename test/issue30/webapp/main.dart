//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Sun, May 19, 2013  1:51:09 PM
// Author: tomyeh

import "package:stream/stream.dart";

void main() {
  new StreamServer(
    uriMapping: {
      "/static/.*": (HttpConnect connect) => connect.server.resourceLoader
        .load(connect, connect.request.uri.path.substring(7)),
      "/": (HttpConnect connect) => connect.forward("/static/test.html"),
      "/.*": (HttpConnect connect) => throw new Http404.fromConnect(connect)
    }).start();
}
