import 'package:stream/stream.dart';

main(){
  StreamServer(
      uriMapping: {
        'get:/': (HttpConnect connect) {
          connect.response.write("GET method");
        },
        'post:/': (HttpConnect connect) {
          connect.response.write("POST method");
        }
      }
  ).start();
}
