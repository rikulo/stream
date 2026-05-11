//Hello Dynamic Contents: the client side code

import "dart:convert" show json;
import "package:web/web.dart";
import "package:http/http.dart" as http;

void main() {
  document.querySelector("#hi")!.onClick.listen((e) async {
    final response = await http.get(Uri.parse("/server-info"));
    final info = json.decode(response.body) as Map;
    document.body!.appendChild(HTMLDivElement()
      ..textContent =
          'Hi there, this is ${info["name"]} ${info["version"]}.');
  });
}
