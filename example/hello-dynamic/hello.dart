//Hello Dynamic Contents: the client side code

import "dart:html";
import "dart:json" as Json;

void main() {
  document.query("#hi").on.click.add((e) {
      new HttpRequest.get("/server-info",
        (request) {
          Map info = Json.parse(request.responseText);
          document.body.appendHtml(
            '<div>Hi there, this is ${info["name"]} ${info["version"]}.</div>');
        });
    });
}