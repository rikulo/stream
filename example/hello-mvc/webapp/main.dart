//Sample of Stream: Hello Templates
library hello_mvc;

import "dart:async";
import "dart:io";
import "package:stream/stream.dart";
import "package:rikulo_commons/logging.dart";
import "package:logging/logging.dart" show Logger, Level;

part "listView.rsp.dart"; //generated from listView.rsp.html

final logger = Logger('test');

//URI mapping
var _mapping = {
  "/": helloMVC
};

///The model: the information of a file.
class FileInfo {
  final String name;
  final bool isDirectory;

  FileInfo(this.name, this.isDirectory);
}

///Controller: prepare the model and then invoke the view, listView
Future helloMVC(HttpConnect connect) {
  //1. prepare the model
  final curdir = Directory.current;
  List<FileInfo> list = [];
  return curdir.list().listen((fse) {
    list.add(FileInfo(fse.path, fse is Directory));
  }).asFuture().then((_) {
    //2. forward to the view
    return listView(connect, path: curdir.path, infos: list);
  });
}

void main() {
  Logger.root.level = Level.INFO;
  logger.onRecord.listen(simpleLoggerHandler);

  StreamServer(uriMapping: _mapping).start();
}
