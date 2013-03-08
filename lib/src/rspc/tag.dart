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
    output.addString(str, compiler.encoding);
  }
  ///Write a string plus a linefeed to [output] in the compiler's encoding.
  void writeln([String str]) {
    if (?str)
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
    String name, desc, args, ctype;
    final attrs = ArgInfo.parse(data);
    for (final nm in attrs.keys) {
      switch (nm) {
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
        default:
          tc.warning("Unknow attribute, $nm");
          break;
      }
    }
    tc.compiler.setPage(name, desc, args, ctype);
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
    for (final nm in attrs.keys) {
      final val = attrs[nm];
      if (val == null)
        tc.error("The $nm attribute requires a value.");
      tc.writeln('\n${tc.pre}response.headers.add("$nm", ${toEL(val)}); //header#${tc.line}');
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

    tc.writeln("\n${tc.pre}var $varnm = new StringBuffer(); _cxs.add(connect); //var#${tc.line}\n"
      "${tc.pre}connect = new HttpConnect.buffer(connect, $varnm); response = connect.response;");
  }
  @override
  void end(TagContext tc) {
    tc.writeln("\n${tc.pre}connect = _cxs.removeLast(); response = connect.response;");
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
      beg = needsVar ? "(var ": "(";
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
  @override
  bool get needsVar => false;
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
  bool get needsVar => true;
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
