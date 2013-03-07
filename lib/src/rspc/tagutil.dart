//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Thu, Mar 07, 2013  9:37:35 AM
// Author: tomyeh
part of stream_rspc;

///Test if the given value is enclosed with `[= ]`.
bool isEL(String val) => val.startsWith("[=") && val.endsWith("]");
///Converts the value to a valid Dart statement
///[quotmark] specifies whether to enclose the expression with `"""` if found
String toEL(String val, {quotmark: false}) {
  var el = isEL(val) ? val.substring(2, val.length - 1).trim(): null;
  return el == null ? val != null ? '"""$val"""': quotmark ? '""': "null":
    el.isEmpty ? '""': quotmark ? '"""\${$el}"""': el;
}

///Parse the information of the arguments.
class ArgInfo {
  ///The first argument, or null if not available
  final String first;
  ///Whether the first argument is an ID.
  final bool isID;
  ///Map of arguments, excluding [first]
  final Map<String, String> args;

  /** Parses the given string into a map of arguments.
   * It assumes the string is in the format of: `arg0="value0" arg1="value1"`
   */
  static Map<String, String> parse(String data)
  => MapUtil.parse(data, backslash:false, defaultValue:"");

  /** Parses the given string.
   *
   * * [idFirst]: whether ID can be the first argument
   * * [strFirst]: whether string can be the first argument
   *
   * Notice: if [idFirst] or [strFirst] is true, the first argument can not
   * be a name-value pair.
   *
   * If both are null, you can use [parse] instead. It is simpler.
   */
  factory ArgInfo(TagContext tc, String data,
      {bool idFirst:true, bool strFirst:true}) {
    String first;
    bool isID = false;
    if (idFirst || strFirst) {
      if (data != null && !(data = data.trim()).isEmpty) {
        final c0 = data[0], len = data.length;
        if (strFirst && (c0 == '"' || c0 == "'")) {
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
          for (; i < len && StringUtil.isChar(
              data[i], lower:true,upper:true, match:"_\$"); ++i)
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
          if (strFirst)
            sb.write(" or ");
        }
        if (strFirst)
          sb.write("a string");
        tc.error(sb.toString());
      }
    }
    return new ArgInfo._(first, isID, parse(data));
  }
  ArgInfo._(this.first, this.isID, this.args);
}