# Stream

[Stream](https://github.com/rikulo/stream) is a Dart web server supporting request routing, filtering, template engine, WebSocket, MVC design pattern and file-based static resources.

* [API Reference](http://www.dartdocs.org/documentation/stream/2.6.1)
* [Discussion](http://stackoverflow.com/questions/tagged/rikulo)
* [Git Repository](https://github.com/rikulo/stream)
* [Issues](https://github.com/rikulo/stream/issues)

Stream is distributed under an Apache 2.0 License.

[![Build Status](https://drone.io/github.com/rikulo/stream/status.png)](https://drone.io/github.com/rikulo/stream/latest)

## Installation

Add this to your `pubspec.yaml` (or create it):

    dependencies:
      stream:


## Usage

* Introduction
* Getting Started with Hello World

### Compile RSP (Rikulo Stream Page) to dart files

There are two ways to compile RSP files into dart files: automatic building with Dart Editor or manual compiling.

> RSP is a template technology allowing developers to create dynamically generated web pages based on HTML, XML or other document types (such as [this](https://github.com/rikulo/stream/blob/master/example/hello-mvc/webapp/listView.rsp.html) and [this](https://github.com/rikulo/stream/blob/master/test/features/webapp/includerView.rsp.html)).

### Build with Dart Editor

To compile your RSP files automatically, you just need to add a build.dart file in the root directory of your project, with the following content:

    import 'package:stream/rspc.dart';
    void main(List<String> arguments) {
      build(arguments);
    }

With this build.dart script, whenever your RSP is modified, it will be re-compiled.

### Compile Manually

To compile a RSP file manually, run `rspc` (RSP compiler) to compile it into the dart file with [command line interface](http://en.wikipedia.org/wiki/Command-line_interface) as follows:

    dart -c lib/rspc.dart -n dir1 dir2 file1 fire2...

A dart file is generated for each RSP file you gave. Fore more options, please run:

    dart -c lib/rspc.dart -h

## Notes to Contributors

### Fork Stream

If you'd like to contribute back to the core, you can [fork this repository](https://help.github.com/articles/fork-a-repo) and send us a pull request, when it is ready.

Please be aware that one of Stream's design goals is to keep the sphere of API as neat and consistency as possible. Strong enhancement always demands greater consensus.

If you are new to Git or GitHub, please read [this guide](https://help.github.com/) first.

## Who Uses

* [Quire](https://quire.io) - a simple, collaborative, multi-level task management tool.
* [Keikai](https://keikai.io) - a sophisticated spreadsheet for big data
