//Sample of Stream: Hello Templates
library hello_mvc;

import "dart:io";
import "package:stream/stream.dart";

part "config.dart";
part "listView.rsp.dart"; //generated from listView.rsp.html

///The model: the information of a file.
class FileInfo {
  final String name;
  final bool isDirectory;

  FileInfo(this.name, this.isDirectory);
}

///Controller: prepare the model and then invoke the view, listView
void helloMVC(HttpConnect connect) {
  //1. prepare the model
  final curdir = new Directory.current();
  List<FileInfo> list = [];

  curdir.list().listen((fse) {
    if (fse is File)
      list.add(new FileInfo(fse.name, false));
    else if (fse is Directory)
      list.add(new FileInfo(fse.path, true));
  })
  ..onError(connect.error)
  ..onDone(() {
    listView(connect, path: curdir.path, infos: list); //forward to the view
  });
}

void main() {
  new StreamServer(uriMapping: _mapping).start();
}
