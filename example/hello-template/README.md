#Hello Templates

This sample demonstrates how to use HTML-like templates to generate dynamic contents in your web application.

The template technology is called RSP (Rikulo Stream Page). It allows developers to create dynamically generated web pages based on HTML, XML or other document types. The technology is called.

Here is an example:

    [* View of Hello Template *]
    [dart]
    part of hello_template;
    [/dart]
    <!DOCTYPE html>
    <html>
      <head>
        <title>Stream: Hello Templates</title>
        <link href="theme.css" rel="stylesheet" type="text/css" />
      </head>
      <body>
        <h1>Stream: Hello Templates</h2>
        <p>Now is [=new Date.now()].</p>
        <p>This page is served by Rikulo Stream [=connect.server.version].</p>
        <p>Please refer to
      <a href="https://github.com/rikulo/stream/tree/master/example/hello-template">Github</a> for how it is implemented.</a>
      </body>
    </html>
