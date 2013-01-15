//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Mon, Jan 14, 2013  4:33:10 PM
// Author: tomyeh

/** Compiles the given [source] RSP document to the given output stream [out].
 * Notice that the caller has to close the output stream by himself.
 */
void compile(Document source, OutputStream out, {
String sourceName, Encoding encoding: Encoding.UTF_8, bool verbose: false}) {
  new Compiler(source, out, sourceName: sourceName, encoding: encoding, verbose: verbose)
    .compile();
}

/** Compiles the RSP document of the given [sourceName] and write the result to
 * the file of given [destinationName].
 *
 * * [fragment] specifies whether the content is a fragment.
 */
void compileFile(String sourceName, {String destinationName, bool verbose : false, 
Encoding encoding : Encoding.UTF_8, bool fragment: false}) {
  final source = new File(sourceName);
  if (!source.existsSync()) {
    print("File not found: ${sourceName}");
    return;
  }
  
  if (destinationName == null) {
    final int i = sourceName.lastIndexOf('.');
    final int j = sourceName.lastIndexOf('/');
    destinationName = i >= 0 && j < i ? "${sourceName.substring(0, i + 1)}dart" : "${sourceName}.dart";
  }
  final dest = new File(destinationName);
  
  if (verbose) {
    final int i = dest.name.lastIndexOf('/') + 1;
    print("Compile ${source.name} to ${i > 0 ? dest.name.substring(i) : dest.name}");
  }
  
  source.readAsString(encoding).then((text) {
    final out = dest.openOutputStream();
    try {
      final parser = new HtmlParser(text, encoding: encoding.name,
        lowercaseElementName: false, lowercaseAttrName: false, cdataOK: true);
      compile(
          fragment ? parser.parseFragment(): parser.parse(),
          out, sourceName: sourceName, encoding: encoding, verbose: verbose);
    } finally {
      out.close();
    }
  });
}

/** Compile changed RSP files. This method shall be called within build.dart,
 * with new Options().arguments as its [arguments].
 */
void build(List<String> arguments) {
  final ArgParser argParser = new ArgParser()
    ..addOption("changed", allowMultiple: true)
    ..addOption("removed", allowMultiple: true)
    ..addFlag("clean", negatable: false)
    ..addFlag("machine", negatable: false);
  
  final ArgResults args = argParser.parse(arguments);
  final List<String> changed = args["changed"];
  final List<String> removed = args["removed"];
  final bool clean = args["clean"];
  
  if (clean) { // clean only
    new Directory.current().list(recursive: true).onFile = (String name) {
      if (name.endsWith(".rsp.dart"))
        new File(name).delete();
    };
    
  } else if (removed.isEmpty && changed.isEmpty) { // full build
    new Directory.current().list(recursive: true).onFile = (String name) {
      bool rsp = name.endsWith(".rsp.html") || name.endsWith(".rsp");
      if (rsp || name.endsWith(".rsf.html") || name.endsWith(".rsf"))
        compileFile(name, fragment: !rsp); //rsf => fragment
    };
    
  } else {
    for (String name in removed) {
      var gennm;
      if (name.endsWith(".rsp.html") || name.endsWith(".rsf.html"))
        gennm = name.substring(0, name.length - 5);
      else if (name.endsWith(".rsp") || name.endsWith(".rsf"))
        gennm = name;

      if (gennm != null) {
        final File gen = new File("$gennm.dart");
        if (gen.existsSync())
          gen.delete();
      }
    }

    for (String name in changed) {
      bool rsp = name.endsWith(".rsp.html") || name.endsWith(".rsp");
      if (rsp || name.endsWith(".rsf.html") || name.endsWith(".rsf"))
        compileFile(name, fragment: !rsp); //rsf => fragment
    }
  }
}
