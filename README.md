#Stream

[Stream](http://rikulo.org/projects/stream) is a Dart web server supporting request routing, filtering, template engine, WebSocket, MVC design pattern and file-based static resources.

* [Home](http://rikulo.org/projects/stream)
* [Documentation](http://docs.rikulo.org/stream/latest)
* [API Reference](http://www.dartdocs.org/documentation/stream/1.5.1)
* [Discussion](http://stackoverflow.com/questions/tagged/rikulo)
* [Git Repository](https://github.com/rikulo/stream)
* [Issues](https://github.com/rikulo/stream/issues)

Stream is distributed under an Apache 2.0 License.

[![Build Status](https://drone.io/github.com/rikulo/stream/status.png)](https://drone.io/github.com/rikulo/stream/latest)

##Installation

Add this to your `pubspec.yaml` (or create it):

    dependencies:
      stream:


##Usage

* [Introduction](http://docs.rikulo.org/stream/latest/Getting_Started/Introduction.html)
* [Getting Started with Hello World](http://docs.rikulo.org/stream/latest/Getting_Started/Hello_World.html)

###Compile RSP (Rikulo Stream Page) to dart files

There are two ways to compile RSP files into dart files: automatic building with Dart Editor or manual compiling.

> RSP is a template technology allowing developers to create dynamically generated web pages based on HTML, XML or other document types (such as [this](https://github.com/rikulo/stream/blob/master/example/hello-mvc/webapp/listView.rsp.html) and [this](https://github.com/rikulo/stream/blob/master/test/features/webapp/includerView.rsp.html)). Please refer to [here](http://docs.rikulo.org/stream/latest/RSP/Fundamentals/RSP_Overview.html) for more information.

###Build with Dart Editor

To compile your RSP files automatically, you just need to add a build.dart file in the root directory of your project, with the following content:

    import 'package:stream/rspc.dart';
    void main(List<String> arguments) {
      build(arguments);
    }

With this build.dart script, whenever your RSP is modified, it will be re-compiled.

###Compile Manually

To compile a RSP file manually, run `rspc` (RSP compiler) to compile it into the dart file with [command line interface](http://en.wikipedia.org/wiki/Command-line_interface) as follows:

    tool/rspc.dart your-rsp-file(s)

A dart file is generated for each RSP file you gave.

Or, you can use a Bash program, [tool/rspc](https://github.com/rikulo/stream/tree/master/tool/rspc), to detect any change of RSP files and compile them automatically.

##Notes to Contributors

###Fork Stream

If you'd like to contribute back to the core, you can [fork this repository](https://help.github.com/articles/fork-a-repo) and send us a pull request, when it is ready.

Please be aware that one of Stream's design goals is to keep the sphere of API as neat and consistency as possible. Strong enhancement always demands greater consensus.

If you are new to Git or GitHub, please read [this guide](https://help.github.com/) first.

##Who Uses

* [Quire](https://quire.io) - a simple, collaborative, multi-level task management tool.
