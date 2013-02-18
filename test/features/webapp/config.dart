//Configuration
part of features;

//URI mapping
var _uriMapping = {
  "/forward": forward,
  "/include": includerView,  //generated from includerView.rsp.html
  "/500": (HttpConnect connect) {
    throw new Exception("something wrong");
  },
  "/recoverable-error": (HttpConnect connect) {
    throw new RecoverError();
  },
  "/log5": (HttpConnect connect) {
    connect.response
      ..headers.contentType = contentTypes["text/plain"]
      ..outputStream.writeString("You see two logs shown on the console");
    connect.close();
  }
};

//Error mapping
var _errMapping = {
  "404": "/404.html",
  "500": (HttpConnect connect) {
    connect.response
      ..headers.contentType = contentTypes["text/html"]
      ..outputStream.writeString("""
<html>
<head><title>500: ${connect.errorDetail.error.runtimeType}</title></head>
<body>
 <h1>500: ${connect.errorDetail.error.message}</h1>
 <pre><code>${connect.errorDetail.stackTrace}</code></pre>
</body>
</html>
        """);
    connect.close();
  },
  "features.RecoverError": (HttpConnect connect) {
    connect.errorDetail = null; //clear error
    connect.response
      ..headers.contentType = contentTypes["text/plain"]
      ..outputStream.writeString("Recovered from an error");
    connect.close();
  }
};

//Filtering
var _filterMapping = {
  "/log.*": (HttpConnect connect, void chain(HttpConnect conn)) {
    connect.server.logger.info("Filter 1: ${connect.request.uri}");
    chain(connect);
  },
  "/log[0-9]*": (HttpConnect connect, void chain(HttpConnect conn)) {
    connect.server.logger.info("Filter 2: ${connect.request.uri}");
    chain(connect);
  }
};