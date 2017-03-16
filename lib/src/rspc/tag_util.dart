//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Thu, Mar 07, 2013  9:37:35 AM
// Author: tomyeh
part of stream_rspc;

///Test if the given character can be used in a variable name.
bool isValidVarChar(String cc, bool firstChar)
 => StringUtil.isChar(cc, lower: true, upper: true, digit: !firstChar, match:"_\$");

/** Test if the given value is enclosed with `[= ]`.
 * If null, false is returned.
 */
bool isEL(String data) {
  for (int i = 0, len = data != null ? data.length: 0; i < len; ++i) {
    final cc = data[i];
    if (cc == '\\')
      ++i;
    else if (cc == '[' && i + 1 < len && data[i + 1] == '=')
      return true;
  }
  return false;
}
/** Converts the given value to a valid Dart statement.
 *
 * * [data] - the value to convert. It can be null.
 * * [direct] - whether it is OK to return an expression, if any, directly
 * without enclosing with `"""`/
 * If true and `data` contains nothing but a single expression, the expression
 * is output directly
 */
String toEL(String data, {direct: true}) {
  if (data == null)
    return direct ? "null": '""';

  final sb = new StringBuffer();
  for (int i = 0, len = data.length; i < len; ++i) {
    final cc = data[i];
    if (cc == '[' && i + 1 < len && data[i + 1] == '=') { //found
      final j = _skipToELEnd(data, i + 2),
          val = data.substring(i + 2, j).trim();
      if (direct && i == 0 && j + 1 == len) //single EL
        return val;
      if (!val.isEmpty)
        sb..write("\${Rsp.nns(")..write(val)..write(")}");

      i = j;
      continue;
    }

    sb.write(cc);
    if (cc == '\\')
      sb.write(data[++i]);
  }
  final val = sb.toString();
  return val.indexOf('"') >= 0 ?
    val.indexOf("'") >= 0 ? '"""$val"""': "'$val'": '"$val"';
}
int _skipToELEnd(String data, int from) {
  String sep;
  int nbkt = 0;
  for (int len = data.length; from < len; ++from) {
    final cc = data[from];
    if (cc == '\\') {
      ++from;
    } else if (sep == null) {
      if (cc == '"' || cc == "'") {
        sep = cc;
      } else if (nbkt == 0 && cc == ']') { //'/' is a valid operator
        return from;
      } else if (cc == '[') {
        ++nbkt;
      } else if (cc == ']') {
        --nbkt;
      }
    } else if (cc == sep) {
      sep = null;
    }
  }
  throw new SyntaxError("", -1, "Expect ']'");
}

/** Parses the given string into a map of arguments.
 * It assumes the string is in the format of: `arg0="value0" arg1="value1"`
 */
Map<String, String> parseArgs(String data)
=> MapUtil.parse(data, backslash:false, defaultValue:"");

/** Output the given text to the generated Dart file.
 * It will generate something like the following to the Dart file:
 *
 *     response.write("$text");
 *
 * Of course, it will escape the text properly if necessary.
 */
void outText(TagContext tc, String text, [int line]) {
  if (text.isEmpty)
    return; //nothing to do

  tc.write('\n${tc.pre}response.write("""');

  for (int i = 0, len = text.length; i < len; ++i) {
    final cc = text[i];
    if (i == 0 && cc == '\n') {
      tc.write('\n'); //first linefeed is ignored, so we have add one more
    } else if (cc == '"') {
      if (i == len - 1) { //end with "
        tc.write('\\');
      } else if (i + 2 < len && text[i + 1] == '"' && text[i + 2] == '"') {
        tc.write('""\\');
        i += 2;
      }
    } else if (cc == '\\' || cc == '\$') {
      tc.write('\\');
    }
    tc.write(cc);
  }

  tc.writeln('"""); //#${line != null ? line: tc.line}');
}

/** Output the given map to the generated Dart file.
 * It will generate something like the following to the Dart file:
 *
 *     {"key1": "value1", "key2": value2_in_EL}
 *
 * A value can contain EL expressions, such as `[=foo_expression]`.
 * However, the keys are output directly, so make sure it does not
 * contain invalid characters.
 */
void outMap(TagContext tc, Map<String, String> map) {
  tc.write("{");
  bool first = true;
  for (final key in map.keys) {
    if (first) first = false;
    else tc.write(", ");

    tc.write("'");
    tc.write(key);
    tc.write("': ");
    tc.write(toEL(map[key])); //Rsp.cat can handle non-string value
  }
  tc.write("}");
}

///Parse the information of the arguments.
class ArgInfo {
  ///The first argument, or null if not available
  final String first;
  ///Whether the first argument is an ID.
  final bool isID;
  ///Map of arguments, excluding [first]
  final Map<String, String> args;

  /** Parses the given string.
   *
   * * [idFirst]: whether ID can be the first argument
   * * [stringFirst]: whether string can be the first argument
   *
   * Notice: if [idFirst] or [stringFirst] is true, the first argument can not
   * be a name-value pair.
   *
   * If both are null, you can use [parse] instead. It is simpler.
   */
  factory ArgInfo(TagContext tc, String data,
      {bool idFirst:true, bool stringFirst:true}) {
    String first;
    bool isID = false;
    if (idFirst || stringFirst) {
      if (data != null && !(data = data.trim()).isEmpty) {
        final c0 = data[0], len = data.length;
        if (stringFirst && (c0 == '"' || c0 == "'")) {
          for (int i = 1; i < len; ++i) {
            final cc = data[i];
            if (cc == c0) {
              first = data.substring(1, i);
              data = data.substring(i + 1);
              break; //done
            }
            if (cc == '\\' && i + 1 < len)
              ++i; //skip
          }
        } else if (idFirst) {
          int i = 0;
          for (; i < len && isValidVarChar(data[i], i == 0); ++i)
            ;
          if (i > 0) {
            first = data.substring(0, i);
            data = data.substring(i).trim();
            isID = true;
            if (!data.isEmpty && data[0] == '=')
              tc.error("Unexpected '=' after an ID, $first"); //highlight common error
          }
        }
      }

      if (first == null) {
        final sb = new StringBuffer("The first argument must be ");
        if (idFirst) {
          sb.write("an ID");
          if (stringFirst)
            sb.write(" or ");
        }
        if (stringFirst)
          sb.write("a string");
        tc.error(sb.toString());
      }
    }
    return new ArgInfo._(first, isID, parseArgs(data));
  }
  ArgInfo._(this.first, this.isID, this.args);
}

typedef void _Output(TagContext tc, String id, Map<String, String> args);

/** A tag simplifies the implementation of simple tags. For example,
 *
 *     import 'package:stream/rspc.dart';
 *     
 *     void main(List<String> arguments) {
 *       tags["m"] = new SimpleTag("m",
 *         (TagContext tc, String id, Map<String, String> args) {
 *           if (id == null)
 *             throw new ArgumentError("id required");
 *           tc.write("\n${tc.pre}response.write(message(connect, $id");
 *           if (args != null && !args.isEmpty) {
 *             tc.write(", ");
 *             outMap(tc, args);
 *           }
 *           tc.writeln("));");
 *         });
 *     
 *       build(arguments,
 *         imports: ["package:foo/server/intl.dart"]);
 *     }
 *
 */
class SimpleTag extends Tag {
  final _Output _output;

  /** Constructors a tag.
   *
   * * [output] - used to generate Dart code into the generated Dart file.
   * You can use [outText] and [toEL] to generate the Dart code.
   * The `id` argument is the first argument if it doesn't have a value.
   * For example, with `[:tag foo1 foo2="abc"]`, `id` will be `foo1` and
   * `args` will be a single entity map. If the first argument is specified
   * with a value, `id` is null and the first argument is part of `args`.
   */
  SimpleTag(String this.name,
      void output(TagContext tc, String id, Map<String, String> args)):
      _output = output;

  @override
  void begin(TagContext tc, String data) {
    final ArgInfo ai = new ArgInfo(tc, data, stringFirst: false);
    _output(tc, ai.first, ai.args);
  }

  @override
  bool get hasClosing => false;
  @override
  final String name;
}
