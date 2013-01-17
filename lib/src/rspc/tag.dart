//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Jan 16, 2013 12:53:42 PM
// Author: tomyeh
part of stream_rspc;

/** The tag execution context.
 */
abstract class TagContext {
  /// The parent tag, or null if not available.
  final Tag parent;
  /** The output stream to generate the Dart code.
   * You can change it to have the child tag to generate the Dart code
   * to, say, a buffer.
   */
  OutputStream output;
  final Compiler compiler;

  TagContext(Tag this.parent, Compiler this.compiler, OutputStream this.output);

  ///The whitespace that shall be generated in front of each line
  String get pre;
  ///Indent for a new block of code. It adds two spaces to [pre].
  String indent();
  ///Un-indent to end a block of code. It removes two spaces from [pre].
  String unindent();

  ///Writes a string to [output] in the compiler's encoding.
  void write(String str) {
    output.writeString(str, compiler.encoding);
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
  void begin(TagContext context, String data, int line);
  /** Called when the ending of a tag is encountered.
   */
  void end(TagContext context);
  /** Whether this tag requires a closing tag, such as  `[/if]`.
   */
  bool get hasClosing;
  /** The tag name.
   */
  String get name;
}

/** A map of tags that RSP compiler uses to handle the tags.
 *
 * The name of tag must start with a lower-case letter (a-z), and it can
 * have only letters (a-z and A-Z).
 */
Map<String, Tag> get tags {
  if (_tags == null) {
    _tags = new Map();
    for (Tag tag in [new PageTag(), new DartTag(), new HeaderTag(),
      new IncludeTag(),
      new ForTag(), new WhileTag(), new IfTag(), new ElseTag()])
      _tags[tag.name] = tag;
  }
  return _tags;
}
Map<String, Tag> _tags;

///The page tag.
class PageTag implements Tag {
  void begin(TagContext tc, String data, int line) {
    String name, desc, args, ctype;
    final attrs = MapUtil.parse(data, backslash:false, defaultValue:"");
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
    tc.compiler.setPage(name, desc, args, ctype, line);
  }
  void end(TagContext tc) {
  }
  bool get hasClosing => false;
  String get name => "page";
}

///The dart tag.
class DartTag implements Tag {
  void begin(TagContext tc, String data, int line) {
    tc.writeln(data);
  }
  void end(TagContext tc) {
  }
  bool get hasClosing => true;
  String get name => "dart";
}

///The header tag to generate HTTP response headers.
class HeaderTag implements Tag {
  void begin(TagContext tc, String data, int line) {
    final attrs = MapUtil.parse(data, backslash:false, defaultValue:"");
    for (final nm in attrs.keys) {
      final val = attrs[nm];
      if (val == null)
        tc.error("The $nm attribute requires a value.");
      tc.writeln('${tc.pre}response.headers.add("$nm", ${_toEL(val)}); //#$line');
    }
  }
  void end(TagContext tc) {
  }
  bool get hasClosing => false;
  String get name => "header";
}

class IncludeTag implements Tag {
  void begin(TagContext tc, String data, int line) {
//TODO
  }
  void end(TagContext tc) {
  }
  bool get hasClosing => false;
  String get name => "include";
}

///A skeletal class for implementing control tags, such as [IfTag] and [WhileTag].
abstract class ControlTag implements Tag {
  void begin(TagContext tc, String data, int line) {
    if (data.isEmpty)
      tc.error("The $name tag requires a condition");

    String beg, end;
    if (data.startsWith('(') && data.endsWith(')')) {
      beg = end = "";
    } else {
      beg = needsVar ? "(var ": "(";
      end = ")";
    }
    tc.writeln("\n${tc.pre}$control $beg$data$end { //#$line");

    tc.indent();
  }
  void end(TagContext tc) {
    tc.unindent();
    tc.writeln("${tc.pre}} //$control");
  }
  bool get hasClosing => true;
  ///The name of the control, such as `if` and `while`. Default: [name].
  String get control => name;
  ///Whether `var` is required in front of the condition
  bool get needsVar => false;
}

///The for tag.
class ForTag extends ControlTag {
  String get name => "for";
  bool get needsVar => true;
}

///The while tag.
class WhileTag extends ControlTag {
  String get name => "while";
}

///The if tag.
class IfTag extends  ControlTag {
  String get name => "if";
}

/** The else tag.
 *
 * The implementation is a bit tricky: it pretends to be an tag without the closing.
 */
class ElseTag implements Tag {
  void begin(TagContext tc, String data, int line) {
    if (!(tc.parent is IfTag))
      tc.error("Unexpected else tag");

    tc.unindent();

    if (data.isEmpty) {
      tc.writeln("\n${tc.pre}} else { //#$line");
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
      tc.writeln("\n${tc.pre}} else if $beg$cond$end { //#$line");
    }

    tc.indent();
  }
  void end(TagContext tc) {
  }
  bool get hasClosing => false;
  String get name => "else";
}
