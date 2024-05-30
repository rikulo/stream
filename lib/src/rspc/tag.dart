//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Jan 16, 2013 12:53:42 PM
// Author: tomyeh
part of stream_rspc;

/** The tag execution context.
 */
abstract class TagContext {
  /// The parent tag context, or null if this is root.
  final TagContext? parent;
  /** The output stream to generate the Dart code.
   * You can change it to have the child tag to generate the Dart code
   * to, say, a buffer.
   */
  IOSink output;
  ///The tag
  final Tag? tag;
  /** The map of arguments. If a tag assigns a non-null value, it means
   * the child tags must be `var`.
   *
   * The key is the argument's name, while the value is the local variable's name.
   * The local variable is used to hold the value.
   */
  Map<String, String>? args;
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

  ///Push a value into the stack.
  void push(value);
  ///Pops the value back
  pop();

  ///Returns the comment containing the line number.
  String getLineNumberComment([int? line])
  => compiler.lineNumber ? ' //#${line??this.line}': '';

  ///Writes a string to [output] in the compiler's encoding.
  void write(String str) {
    output.write(str);
  }
  ///Writes a character code.
  void writeCharCode(int code) {
    output.writeCharCode(code);
  }
  ///Write a string plus a linefeed to [output] in the compiler's encoding.
  void writeln([String? str]) {
    if (str != null)
      write(str);
    write("\n");
  }
  ///Throws an exception (and stops execution).
  Never error(String message, [int line]);
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

  @override
  String toString() => "[$name]";
}

/** A map of tags that RSP compiler uses to handle the tags.
 *
 * The name of tag must start with a lower-case letter (a-z), and it can
 * have only letters (a-z and A-Z).
 */
late Map<String, Tag> tags = (() {
    final tags = HashMap<String, Tag>();
    for (Tag tag in [PageTag(), DartTag(), HeaderTag(),
        IncludeTag(), ForwardTag(), VarTag(),
        JsonTag(), JsonJsTag(),
        ForTag(), WhileTag(), IfTag(), ElseTag()])
      tags[tag.name] = tag;
    return tags;
  })();

///The page tag.
class PageTag extends Tag {
  @override
  void begin(TagContext tc, String data) {
    String? partOf, parts, imports, name, desc, args, ctype, dart,
      lastModified, etag;

    final attrs = parseArgs(data);
    attrs.forEach((nm, val) {
      switch (nm) {
        case "partOf":
        case "part-of":
          partOf = val;
          break;
        case "part":
          parts = val;
          break;
        case "import":
          imports = val;
          break;
        case "name":
          name = val;
          break;
        case "content-type":
        case "contentType":
          ctype = val;
          break;
        case "args":
        case "arguments":
          if ((args = val.trim()).isEmpty) args = null;
          break;
        case "description":
          desc = val;
          break;
        case "dart":
          dart = val;
          break;
        case "last-modified":
        case "lastModified":
          lastModified = val;
          break;
        case "etag":
          etag = val;
          break;
        default:
          tc.warning("Unknown attribute: $nm");
          break;
      }
    });
    tc.compiler.setPage(partOf, parts, imports, name, desc, args, ctype, dart,
      lastModified, etag);
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
    final attrs = parseArgs(data);
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
      tc.writeln(';${tc.getLineNumberComment()}');
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
 * > Notice: since 1.5, you can use `[include]` inside whatever tags.
 */
class IncludeTag extends Tag {
  @override
  void begin(TagContext tc, String data) {
    tc.data = ArgInfo(tc, data);
    tc.args = LinkedHashMap<String, String>(); //order is important
  }
  @override
  void end(TagContext tc) {
    final argInfo = tc.data as ArgInfo;
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
Map<String, String> _mergeArgs(Map<String, String> dst, Map<String, String>? src) {
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
    tc.data = ArgInfo(tc, data);
    tc.args = LinkedHashMap<String, String>(); //order is important
  }
  @override
  void end(TagContext tc) {
    final argInfo = tc.data as ArgInfo;
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
    final argInfo = ArgInfo(tc, data, stringFirst: false);
    final parentArgs = tc.parent?.args;
    var var1 = parentArgs != null ?
          (parentArgs[argInfo.first] = tc.nextVar()): argInfo.first,
      var2 = tc.nextVar();
    tc..push(var1)..push(var2);

    if (tc.parent?.args == null) var1 = "_${var1}_";
    tc.writeln("\n${tc.pre}final $var1 = StringBuffer(), $var2 = connect;${tc.getLineNumberComment()}\n"
      "${tc.pre}connect = HttpConnect.stringBuffer(connect, $var1); response = connect.response;");
  }
  @override
  void end(TagContext tc) {
    final var2 = tc.pop() as String, var1 = tc.pop() as String;
    tc.writeln("\n${tc.pre}connect = $var2; response = connect.response;");
    if (tc.parent?.args == null) {
      tc.writeln("${tc.pre}final $var1 = _${var1}_.toString();");
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
 *     <script id="name" type="text/plain">jsonEncode(expression)</script>
 *
 * And, you can retrieve it in Dart with:
 *
 *     var data = jsonDecode(document.query("#data").innerHtml)
 */
class JsonTag extends Tag {
  @override
  void begin(TagContext tc, String data) {
    if (data.isEmpty)
      tc.error("Expect a variable name");

    final len = data.length;
    int i = 0;
    for (; i < len && isValidVarCharCode(data.codeUnitAt(i), i == 0); ++i)
      ;
    if (i == 0)
      tc.error("Expect a variable name, not '${data[0]}'");

    final nm = data.substring(0, i);
    for (; i < len && $whitespaces.contains(data.codeUnitAt(i)); ++i)
      ;
    if (i >= len || data.codeUnitAt(i) != $equal)
      tc.error("Expect '=', not '${data[i]}");

    final val = data.substring(i + 1).trim();
    if (val.isEmpty)
      tc.error("Expect an expression");

    tc.writeln("""${tc.pre}response..write('<script type="text/plain" id="')${tc.getLineNumberComment()}""");
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
 *     <script>name=jsonEcode(expression)</script>
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
    for (; i < len && isValidVarCharCode(data.codeUnitAt(i), i == 0); ++i)
      ;
    if (i == 0)
      tc.error("Expect a variable name, not '${data[0]}'");

    final nm = data.substring(0, i);
    for (; i < len && $whitespaces.contains(data.codeUnitAt(i)); ++i)
      ;
    if (i >= len || data.codeUnitAt(i) != $equal)
      tc.error("Expect '=', not '${data[i]}");

    final val = data.substring(i + 1).trim();
    if (val.isEmpty)
      tc.error("Expect an expression");

    tc.writeln('\n${tc.pre}response..write("<script>")..write(${toEL(nm)})..write("=")${tc.getLineNumberComment()}');
    tc.writeln("${tc.pre} ..write(Rsp.json($val))..writeln('</script>');");
  }
  @override
  bool get hasClosing => false;
  @override
  String get name => "json-js";
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
    tc.writeln("\n${tc.pre}$name $beg$data$end {${tc.getLineNumberComment()}");
    tc.indent();
  }
  @override
  void end(TagContext tc) {
    tc.unindent();
    tc.writeln("${tc.pre}} //$name");
  }
  @override
  bool get hasClosing => true;
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
    if (!(tc.parent?.tag is IfTag))
      tc.error("Unexpected else tag");

    tc.unindent();

    if (data.isEmpty) {
      tc.writeln("\n${tc.pre}} else {${tc.getLineNumberComment()}");
    } else {
      String cond;
      if (data.length < 4 || !data.startsWith("if")
      || !$whitespaces.contains(data.codeUnitAt(2))
      || (cond = data.substring(3).trim()).isEmpty)
        tc.error("Unexpected $data");

      String beg, end;
      if (cond.startsWith('(') && cond.endsWith(')')) {
        beg = end = "";
      } else {
        beg = "(";
        end = ")";
      }
      tc.writeln("\n${tc.pre}} else if $beg$cond$end {${tc.getLineNumberComment()}");
    }

    tc.indent();
  }
  @override
  bool get hasClosing => false;
  @override
  String get name => "else";
}
