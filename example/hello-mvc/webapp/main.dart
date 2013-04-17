//Sample of Stream: Hello Templates
library hello_mvc;

import "dart:async";
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
Future helloMVC(HttpConnect connect) {
  //1. prepare the model
  final completer = new Completer();
  final curdir = new Directory.current();
  List<FileInfo> list = [];

  curdir.list().listen((fse) {
    list.add(new FileInfo(fse.path, fse is Directory));
  })
  ..onError((err) => completer.completeError(err))
  ..onDone(() {
    listView(connect, path: curdir.path, infos: list).then((_) { //forward to the view
      completer.complete();
    }).catchError((err) => completer.completeError(err));
    //TODO: if Stream.done is supported (issue 9725), we don't need completer
  });
  return completer.future;
}

void main() {
  new StreamServer(uriMapping: _mapping).start();
}
