//Configuration
part of features;

//URI mapping
var _uriMapping = {
  "/forward": forward,
  "/include": includerView,  //generated from includerView.rsp.html
  "/search": search,
  "/(group:g[a-z]*p)/(matching:ma[a-z]*)": (HttpConnect connect) {
    connect.response
      ..headers.contentType = contentTypes["text/plain"]
      ..write("Group Matching: ${connect.dataset['group']} and ${connect.dataset['matching']}");
  },
  "/old-link(extra:.*)": "/new-link(extra)/more",
  "/new-link.*": (HttpConnect connect) {
    connect.response
      ..headers.contentType = contentTypes["text/plain"]
      ..write("old-link forwarded to ${connect.request.uri}");
  },
  "/500": (HttpConnect connect) {
    throw new Exception("something wrong");
  },
  "/recoverable-error": (HttpConnect connect) {
    throw new RecoverError();
  },
  "/log5": (HttpConnect connect) {
    connect.response
      ..headers.contentType = contentTypes["text/plain"]
      ..write("You see two logs shown on the console");
  },
  "/longop": (HttpConnect connect) {
    connect.response
      ..headers.contentType = contentTypes["text/html"]
      ..write("<html><body><p>This is used to test if client aborts the connection</p>"
        "<p>Close the browser tab as soon as possible (in 10 secs)</p>");
    return new Future.delayed(const Duration(seconds: 10), () {
      connect.response.write("<p>You shall close the browser tab before seeing this</p></body></html>");
    });
  }
};

//Error mapping
var _errMapping = {
  "404": "/404.html",
  "500": (HttpConnect connect) {
    connect.response
      ..headers.contentType = contentTypes["text/html"]
      ..write("""
<html>
<head><title>500: ${connect.errorDetail.error.runtimeType}</title></head>
<body>
 <h1>500: ${connect.errorDetail.error}</h1>
 <pre><code>${connect.errorDetail.stackTrace}</code></pre>
</body>
</html>
        """);
  },
  "features.RecoverError": (HttpConnect connect) {
    connect.errorDetail = null; //clear error
    connect.response
      ..headers.contentType = contentTypes["text/plain"]
      ..write("Recovered from an error");
  }
};

//Filtering
var _filterMapping = {
  "/log.*": (HttpConnect connect, Future chain(HttpConnect conn)) {
    connect.server.logger.info("Filter 1: ${connect.request.uri}");
    return chain(connect);
  },
  "/log[0-9]*": (HttpConnect connect, Future chain(HttpConnect conn)) {
    connect.server.logger.info("Filter 2: ${connect.request.uri}");
    return chain(connect);
  }
};