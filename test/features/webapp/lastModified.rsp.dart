//Auto-generated by RSP Compiler
//Source: ../lastModified.rsp.html
part of features;

/// Template, lastModified, for rendering the view.
Future lastModified(HttpConnect connect) async {
  //ignore: unused_local_variable
  var response = connect.response;
  if (!Rsp.init(connect, "text/html; charset=utf-8",
  etag: "abc123"))
    return null;

  response.write("""<html>
  <head>
    <title>ETag Test</title>
  </head>
  <body>
    Please open the debug console and reload to see if 304 is sent back by
    the server.
  </body>
</html>
""");

  return null;
}
