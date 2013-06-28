//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Jan 16, 2013 12:53:42 PM
// Author: tomyeh
part of stream_rspc;

/** The tag execution context.
 */
abstract class TagContext {
  /// The parent tag context, or null if this is root.
  final TagContext parent;
  /** The output stream to generate the Dart code.
   * You can change it to have the child tag to generate the Dart code
   * to, say, a buffer.
   */
  IOSink output;
  ///The tag
  final Tag tag;
  /** The map of arguments. If a tag assigns a non-null value, it means
   * the child tags must be `var`.
   *
   * The key is the argument's name, while the value is the local variable's name.
   * The local variable is used to hold the value.
   */
  Map<String, String> args;
  ///Tag-specific data. A tag can store anything here.
  var data;
  final Compiler compiler;
  ///The line number of the starting of this context
  int get line;

  TagContext(this.parent, this.tag, this.compiler, this.output);

  ///Returns the next available name for a new local variable
  String nextVar();
  ///The whitespace that shall be generated in front of each line
  String get pre;
  ///Indent for a new block of code. It adds two spaces to [pre].
  String indent();
  ///Un-indent to end a block of code. It removes two spaces from [pre].
  String unindent();

  ///Writes a string to [output] in the compiler's encoding.
  void write(String str) {
    output.write(str);
  }
  ///Write a string plus a linefeed to [output] in the compiler's encoding.
  void writeln([String str]) {
    if (str != null)
      write(str);
    write("\n");
  }
  ///Throws an exception (and stops execution).
  void error(String message, [int line]);
  ///Display an warning.
  void warning(String message, [int line]);
}

/**
 * A tag.
 */
abstract class Tag {
  /** Called when the beginning of a tag is encountered.
   */
  void begin(TagContext context, String data);
  /** Called when the ending of a tag is encountered.
   */
  void end(TagContext context) {
  }
  /** Whether this tag requires a closing tag, such as  `[/if]`.
   */
  bool get hasClosing;
  /** Whether this tag generates any content to the response's output.
   * Notice that it is not about the generated Dart file.
   * Most tags don't need to override this (return false), since they
   * don't generate something like `response.write(...)` to the Dart file.
   */
  bool get hasContent => false;
  /** The tag name.
   */
  String get name;

  String toString() => "[$name]";
}

/** A map of tags that RSP compiler uses to handle the tags.
 *
 * The name of tag must start with a lower-case letter (a-z), and it can
 * have only letters (a-z and A-Z).
 */
Map<String, Tag> get tags {
  if (_tags == null) {
    _tags = new HashMap();
    for (Tag tag in [new PageTag(), new DartTag(), new HeaderTag(),
      new IncludeTag(), new ForwardTag(), new VarTag(),
      new JsonTag(), new JsonJsTag(), new ScriptTag(),
      new ForTag(), new WhileTag(), new IfTag(), new ElseTag()])
      _tags[tag.name] = tag;
  }
  return _tags;
}
Map<String, Tag> _tags;

///The page tag.
class PageTag extends Tag {
  @override
  void begin(TagContext tc, String data) {
    String partOf, imports, name, desc, args, ctype, lastModified;
    final attrs = ArgInfo.parse(data);
    for (final nm in attrs.keys) {
      switch (nm) {
        case "partOf":
        case "part-of":
          partOf = attrs[nm];
          break;
        case "import":
          imports = attrs[nm];
          break;
        case "name":
          name = attrs[nm];
          break;
        case "content-type":
        case "contentType":
          ctype = attrs[nm];
          break;
        case "args":
        case "arguments":
          args = attrs[nm];
          if (args.trim().isEmpty)
            args = null;
          break;
        case "description":
          desc = attrs[nm];
          break;
        case "last-modified":
        case "lastModified":
          lastModified = attrs[nm];
          break;
        default:
          tc.warning("Unknow attribute, $nm");
          break;
      }
    }
    tc.compiler.setPage(partOf, imports, name, desc, args, ctype, lastModified);
  }
  @override
  bool get hasClosing => false;
  @override
  String get name => "page";
}

///The dart tag.
class DartTag extends Tag {
  @override
  void begin(TagContext tc, String data) {
    if (!data.isEmpty)
      tc.writeln(data);
  }
  @override
  bool get hasClosing => true;
  @override
  String get name => "dart";
}

///The header tag to generate HTTP response headers.
class HeaderTag extends Tag {
  @override
  void begin(TagContext tc, String data) {
    final attrs = ArgInfo.parse(data);
    if (!attrs.isEmpty) {
      tc.write("\n${tc.pre}response.headers");
      bool first = true;
      for (final nm in attrs.keys) {
        final val = attrs[nm];
        if (val == null)
          tc.error("The $nm attribute requires a value.");

        if (first) first = false;
        else tc.write("\n${tc.pre}  ");
        tc.write('..add("$nm", ${toEL(val)})');
      }
      tc.writeln('; //header#${tc.line}');
    }
  }
  @override
  bool get hasClosing => false;
  @override
  String get name => "header";
}

/** The include tag. There are two formats:
 *
 *     [include "uri"]
 *
 *     [include method_name arg0="value0" arg1="value1"]
 *
 * where `uri`, `value0` and `value1` can be an expression.
 *
 * Notice that the include tag must be top-level. In other words, it can be
 * placed inside others.
 */
class IncludeTag extends Tag {
  @override
  void begin(TagContext tc, String data) {
    tc.data = new ArgInfo(tc, data);
    tc.args = new LinkedHashMap(); //order is important
  }
  @override
  void end(TagContext tc) {
    final argInfo = tc.data;
    final args = _mergeArgs(argInfo.args, tc.args);
    if (argInfo.isID)
      tc.compiler.include(argInfo.first, args, tc.line);
    else
      tc.compiler.includeUri(argInfo.first, args, tc.line);
  }

  @override
  bool get hasClosing => true;
  @override
  String get name => "include";
}
///merge arguments
Map<String, dynamic> _mergeArgs(Map<String, dynamic> dst, Map<String, String> src) {
  if (src != null)
    for (final nm in src.keys)
      dst[nm] = "[=${src[nm]}.toString()]";
  return dst;
}

/** The forward tag. There are two formats:
 *
 *     [forward "uri"]
 *
 *     [forward method_name arg0="value0" arg1="value1"]
 *
 * where `uri`, `value0` and `value1` can be an expression.
 *
 * Notice that the cotent following the forward tag won't be rendered.
 *
 * Unlike the include tag, it can be placed inside another tags.
 */
class ForwardTag extends Tag {
  @override
  void begin(TagContext tc, String data) {
    tc.data = new ArgInfo(tc, data);
    tc.args = new LinkedHashMap(); //order is important
  }
  @override
  void end(TagContext tc) {
    final argInfo = tc.data;
    final args = _mergeArgs(argInfo.args, tc.args);
    if (argInfo.isID)
      tc.compiler.forward(argInfo.first, args, tc.line);
    else
      tc.compiler.forwardUri(argInfo.first, args, tc.line);
  }
  @override
  bool get hasClosing => true;
  @override
  String get name => "forward";
}

/** The var tag. It defines a variable or an argument passed to [IncludeTag]
 * or [ForwardTag]
 */
class VarTag extends Tag {
  @override
  void begin(TagContext tc, String data) {
    final argInfo = new ArgInfo(tc, data, strFirst: false);
    final parentArgs = tc.parent.args;
    var varnm = tc.data
      = parentArgs != null ? (parentArgs[argInfo.first] = tc.nextVar()): argInfo.first;

    tc.writeln("\n${tc.pre}var $varnm = new StringBuffer(); _cs_.add(connect); //var#${tc.line}\n"
      "${tc.pre}connect = new HttpConnect.stringBuffer(connect, $varnm); response = connect.response;");
  }
  @override
  void end(TagContext tc) {
    tc.writeln("\n${tc.pre}connect = _cs_.removeLast(); response = connect.response;");
    if (tc.parent.args == null) {
      String varnm = tc.data;
      tc.writeln("${tc.pre}$varnm = $varnm.toString();");
    }
  }
  @override
  bool get hasClosing => true;
  @override
  String get name => "var";
}

/** The json tag. It generates a JavaScript object by converting
 * the given Dart expression into a JSON object.
 *
 *     [:json name=expression /]
 *
 * It generates
 *
 *     <script id="name" type="text/plain">Json.stringify(expression)</script>
 *
 * And, you can retrieve it in Dart with:
 *
 *     var data = Json.parse(document.query("#data").innerHtml)
 */
class JsonTag extends Tag {
  @override
  void begin(TagContext tc, String data) {
    if (data.isEmpty)
      tc.error("Expect a variable name");

    final len = data.length;
    int i = 0;
    for (; i < len && isValidVarChar(data[i], i == 0); ++i)
      ;
    if (i == 0)
      tc.error("Expect a variable name, not '${data[0]}'");

    final nm = data.substring(0, i);
    for (; i < len && StringUtil.isChar(data[i], whitespace: true); ++i)
      ;
    if (i >= len || data[i] != '=')
      tc.error("Expect '=', not '${data[i]}");

    final val = data.substring(i + 1).trim();
    if (val.isEmpty)
      tc.error("Expect an expression");

    tc.writeln("""${tc.pre}response..write('<script type="text/plain" id="') //json#${tc.line}""");
    tc.writeln("""${tc.pre} ..write(${toEL(nm)})..write('">')""");
    tc.writeln("${tc.pre} ..write(Rsp.json($val))..writeln('</script>');");
  }
  @override
  bool get hasClosing => false;
  @override
  String get name => "json";
}

/** The json-js tag. It generates a JavaScript object by converting
 * the given Dart expression into a JSON object.
 *
 *     [:json-js name=expression ]
 *
 * Then, it generates a SCRIPT tag something similar as follows:
 *
 *     <script>name=Json.stringify(expression)</script>
 *
 * Notice: it is a JavaScript object. If you'd like to handle it in Dart,
 * it is better to use [JsonTag] instead.
 */
class JsonJsTag extends Tag {
  @override
  void begin(TagContext tc, String data) {
    if (data.isEmpty)
      tc.error("Expect a variable name");

    final len = data.length;
    int i = 0;
    for (; i < len && isValidVarChar(data[i], i == 0); ++i)
      ;
    if (i == 0)
      tc.error("Expect a variable name, not '${data[0]}'");

    final nm = data.substring(0, i);
    for (; i < len && StringUtil.isChar(data[i], whitespace: true); ++i)
      ;
    if (i >= len || data[i] != '=')
      tc.error("Expect '=', not '${data[i]}");

    final val = data.substring(i + 1).trim();
    if (val.isEmpty)
      tc.error("Expect an expression");

    tc.writeln('\n${tc.pre}response..write("<script>")..write(${toEL(nm)})..write("=") //json-js#${tc.line}');
    tc.writeln("${tc.pre} ..write(Rsp.json($val))..writeln('</script>');");
  }
  @override
  bool get hasClosing => false;
  @override
  String get name => "json-js";
}

/** The script tag to generate `SCRIPT` tag for loading Dart script.
 *
 * For example,
 *
 *     [:script src="/script/foo.dart"]
 *
 * will generate if the browser supports Dart
 *
 *     <script type="application/dart" src="/script/foo.dart"></script>
 *     <script src="/packages/browser/dart.js"></script>
 *
 * On the other hand, if the browser doesn't support Dart
 * or [Rsp.disableDartScript] is true, it always generate
 *
 *     <script src="/script/foo.dart.js"></script>
 */
class ScriptTag extends Tag {
  @override
  void begin(TagContext tc, String data) {
    String src;
    bool bootstrap = true;
    final attrs = ArgInfo.parse(data);
    for (final nm in attrs.keys) {
      switch (nm) {
        case "src":
          src = attrs[nm];
          break;
        case "bootstrap":
          bootstrap = attrs[nm] == "true";
          break;
        default:
          tc.warning("Unknow attribute, $nm");
          break;
      }
    }
    if (src == null)
      tc.error("The src attribute is required");
    tc.writeln('\n${tc.pre}response.write(Rsp.script(connect, ${toEL(src)}, $bootstrap)); //script#${tc.line}');
  }
  @override
  bool get hasClosing => false;
  @override
  String get name => "script";
}

///A skeletal class for implementing control tags, such as [IfTag] and [WhileTag].
abstract class ControlTag extends Tag {
  @override
  void begin(TagContext tc, String data) {
    if (data.isEmpty)
      tc.error("The $name tag requires a condition");

    String beg, end;
    if (data.startsWith('(') && data.endsWith(')')) {
      beg = end = "";
    } else {
      beg = needsVar_ ? "(var ": "(";
      end = ")";
    }
    tc.writeln("\n${tc.pre}$control $beg$data$end { //$name#${tc.line}");
    tc.indent();
  }
  @override
  void end(TagContext tc) {
    tc.unindent();
    tc.writeln("${tc.pre}} //$control");
  }
  @override
  bool get hasClosing => true;
  ///The name of the control, such as `if` and `while`. Default: [name].
  @override
  String get control => name;
  ///Whether `var` is required in front of the condition
  bool get needsVar_ => false;
}

/** The for tag. There are two formats:
 *
 *     [for name in collection]
 *     [/for]
 *
 *     [for statement1; condition; statement2 ]
 *     [/for]
 */
class ForTag extends ControlTag {
  @override
  String get name => "for";
  @override
  bool get needsVar_ => true;
}

/** The while tag.
 *
 *     [while condition]
 *     [/while]
 */
class WhileTag extends ControlTag {
  @override
  String get name => "while";
}

/** The if tag.
 *
 *      [if condition]
 *      [/if]
 */
class IfTag extends  ControlTag {
  @override
  String get name => "if";
}

/** The else tag.
 *
 *      [if condition1]
 *      [else if condition2]
 *      [else]
 *      [/if]
 */
class ElseTag extends Tag {
  //The implementation is a bit tricky: it pretends to be an tag without the closing.
  @override
  void begin(TagContext tc, String data) {
    if (!(tc.parent.tag is IfTag))
      tc.error("Unexpected else tag");

    tc.unindent();

    if (data.isEmpty) {
      tc.writeln("\n${tc.pre}} else { //else#${tc.line}");
    } else {
      String cond;
      if (data.length < 4 || !data.startsWith("if")
      || !StringUtil.isChar(data[2], whitespace:true)
      || (cond = data.substring(3).trim()).isEmpty)
        tc.error("Unexpected $data");

      String beg, end;
      if (cond.startsWith('(') && cond.endsWith(')')) {
        beg = end = "";
      } else {
        beg = "(";
        end = ")";
      }
      tc.writeln("\n${tc.pre}} else if $beg$cond$end { //else#${tc.line}");
    }

    tc.indent();
  }
  @override
  bool get hasClosing => false;
  @override
  String get name => "else";
}
