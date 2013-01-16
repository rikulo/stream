//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Wed, Jan 16, 2013 12:53:42 PM
// Author: tomyeh
part of stream_rspc;

/** The tag execution context.
 */
class TagContext {
  /// The parent tag, or null if not available.
  final Tag parent;
  /** The output stream to generate the Dart code.
   * You can change it to have the child tag to generate the Dart code
   * to, say, a buffer.
   */
  OutputStream output;
  ///The whitespace that shall be generated in front of each line
  String pre;
  final Compiler compiler;

  TagContext(Tag this.parent, OutputStream this.output,
    String this.pre, Compiler this.compiler);

  void write(String str) {
    output.writeString(str, compiler.encoding);
  }
  void writeln([String str]) {
    if (?str)
      write(str);
    write("\n");
  }
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
    for (Tag tag in [new PageTag(), new DartTag(), new IncludeTag(),
      new ForTag(), new IfTag(), new ElseTag()])
      _tags[tag.name] = tag;
  }
  return _tags;
}
Map<String, Tag> _tags;

///The page tag.
class PageTag implements Tag {
  void begin(TagContext context, String data) {
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
          context.compiler.warning("Unknow attribute, $nm");
          break;
      }
    }
    context.compiler.setPage(name, desc, args, ctype);
  }
  void end(TagContext context) {
  }
  bool get hasClosing => false;
  final String name = "page";
}

///The dart tag.
class DartTag implements Tag {
  void begin(TagContext context, String data) {
    context.writeln(data);
  }
  void end(TagContext context) {
  }
  bool get hasClosing => true;
  final String name = "dart";
}

///The include tag.
class IncludeTag implements Tag {
  void begin(TagContext context, String data) {
//TODO
  }
  void end(TagContext context) {
  }
  bool get hasClosing => false;
  final String name = "include";
}

///The for tag.
class ForTag implements Tag {
  void begin(TagContext context, String data) {

  }
  void end(TagContext context) {

  }
  bool get hasClosing => true;
  final String name = "for";
}

///The if tag.
class IfTag implements Tag {
  void begin(TagContext context, String data) {

  }
  void end(TagContext context) {

  }
  bool get hasClosing => true;
  final String name = "if";
}

/** The else tag.
 *
 * The implementation is a bit tricky: it pretends to be an tag without the closing.
 */
class ElseTag implements Tag {
  void begin(TagContext context, String data) {

  }
  void end(TagContext context) {
  }
  bool get hasClosing => false;
  final String name = "unless";
}