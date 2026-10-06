# Stream

[Stream](https://github.com/rikulo/stream) is a Dart web server supporting request routing, filtering, template engine, WebSocket, MVC design pattern and file-based static resources.

* [Home](https://github.com/rikulo/stream)
* [API Reference](https://pub.dev/documentation/stream/latest/)
* [Discussion](https://stackoverflow.com/questions/tagged/rikulo)
* [Git Repository](https://github.com/rikulo/stream)
* [Issues](https://github.com/rikulo/stream/issues)

## Installation

Add this to your `pubspec.yaml` (or create it):

    dependencies:
      stream:


## Usage

See [the examples](https://github.com/rikulo/stream/tree/master/example), from serving static files to RSP templating, MVC and Ajax.

### Compile RSP (Rikulo Stream Page) to Dart files

> RSP is a template technology allowing developers to create dynamically generated web pages based on HTML, XML or other document types (such as [this](https://github.com/rikulo/stream/blob/master/example/hello-mvc/webapp/listView.rsp.html) and [this](https://github.com/rikulo/stream/blob/master/test/features/webapp/includerView.rsp.html)).

To compile RSP files, run the `rspc` executable from a Dart package that depends on Stream:

    dart run stream:rspc -n dir1 dir2 file1 file2...

A Dart file is generated for each RSP file you provide (e.g., `foo.rsp.html` to `foo.rsp.dart`). For more options, run:

    dart run stream:rspc -h

Alternatively, activate it globally and run `rspc` directly:

    dart pub global activate stream
    rspc -n dir1 dir2 file1 file2...

To compile from your own build script, call `compileFile` instead:

    import 'package:stream/rspc.dart';

    Future<void> main() async {
      await compileFile("webapp/home.rsp.html", newer: true);
    }

## Notes to Contributors

### Fork Stream

If you'd like to contribute back to the core, you can [fork this repository](https://help.github.com/articles/fork-a-repo) and send us a pull request, when it is ready.

Please be aware that one of Stream's design goals is to keep the sphere of API as neat and consistency as possible. Strong enhancement always demands greater consensus.

If you are new to Git or GitHub, please read [this guide](https://help.github.com/) first.

### Compile Test and Example RSP Files

To recompile the RSP files under `test/` and `example/`, run `tool/rspc` from the repository root (only newer files; `tool/rspc -f` compiles all).

## Who Uses

* [Quire](https://quire.io) - a simple, collaborative, multi-level task management tool.
* [Keikai](https://keikai.io) - a sophisticated spreadsheet for big data
* [Ottava](https://ottava.io) - a no-code SaaS platform simplifying data management, chart creation, and data analysis.
