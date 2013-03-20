//Hello Dynamic Contents: the client side code

import "dart:html";
import "dart:json" as Json;

void main() {
  document.query("#hi").onClick.listen(
    (e) {
      HttpRequest.request("/server-info").then(
        (request) {
          Map info = Json.parse(request.responseText);
          document.body.appendHtml(
            '<div>Hi there, this is ${info["name"]} ${info["version"]}.</div>');
        });
    });
}