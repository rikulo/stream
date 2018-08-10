//Hello Dynamic Contents: the client side code

import "dart:html";
import "dart:convert" show json;

void main() {
  document.querySelector("#hi").onClick
    .listen((e) {
      HttpRequest.request("/server-info")
      .then((request) {
        Map info = json.decode(request.responseText);
        document.body.appendHtml(
          '<div>Hi there, this is ${info["name"]} ${info["version"]}.</div>');
      });
    });
}