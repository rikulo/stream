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
  void end(TagContext);
  /** Whether this tag requires a closing tag, such as  `[/if]`.
   */
  bool get hasClosing;
  /** Whether to skip the processing of tags between the beginning and the ending.
   * For example, [DartTag] does it this way.
   */
  bool get isBlind;
}

/** A map of tags that RSP compiler uses to handle the tags.
 *
 * The name of tag must start with a lower-case letter (a-z), and it can
 * have only letters (a-z and A-Z).
 */
Map<String, Tag> tags = {
  "page": new PageTag(),
  "dart": new DartTag(),
  "include": new IncludeTag(),
  "for": new ForTag(),
  "if": new IfTag(),
  "else": new ElseTag()
};

///The page tag.
class PageTag implements Tag {
  void begin(TagContext context, String data) {

  }
  void end(TagContext) {
  }
  bool get hasClosing => false;
  bool get isBlind => false;
}
///The dart tag.
class DartTag implements Tag {
  void begin(TagContext context, String data) {

  }
  void end(TagContext) {

  }
  bool get hasClosing => true;
  bool get isBlind => true;
}

///The include tag.
class IncludeTag implements Tag {
  void begin(TagContext context, String data) {
//TODO
  }
  void end(TagContext) {
  }
  bool get hasClosing => false;
  bool get isBlind => false;
}

///The for tag.
class ForTag implements Tag {
  void begin(TagContext context, String data) {

  }
  void end(TagContext) {

  }
  bool get hasClosing => true;
  bool get isBlind => false;
}

///The if tag.
class IfTag implements Tag {
  void begin(TagContext context, String data) {

  }
  void end(TagContext) {

  }
  bool get hasClosing => true;
  bool get isBlind => false;
}

/** The else tag.
 *
 * The implementation is a bit tricky: it pretends to be an tag without the closing.
 */
class ElseTag implements Tag {
  void begin(TagContext context, String data) {

  }
  void end(TagContext) {
  }
  bool get hasClosing => false;
  bool get isBlind => false;
}
