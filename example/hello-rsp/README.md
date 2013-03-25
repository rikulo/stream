#Hello RSP

This sample demonstrates how to use HTML-like templates to generate dynamic contents in your web application.

The template technology is called RSP (Rikulo Stream Page). It allows developers to create dynamically generated web pages based on HTML, XML or other document types.

Here is an example:

    [!-- View of Hello RSP --]
    [dart]
    part of hello_rsp;
    [/dart]
    <!DOCTYPE html>
    <html>
      <head>
        <title>Stream: Hello RSP</title>
        <link href="theme.css" rel="stylesheet" type="text/css" />
      </head>
      <body>
        <h1>Stream: Hello RSP</h1>
        <p>Now is [=new DateTime.now()].</p>
        <p>This page is served by Rikulo Stream [=connect.server.version].</p>
        <p>Please refer to
      <a href="https://github.com/rikulo/stream/tree/master/example/hello-rsp">Github</a> for how it is implemented.</a>
      </body>
    </html>
