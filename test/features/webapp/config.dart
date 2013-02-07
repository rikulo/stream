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