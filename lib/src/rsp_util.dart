//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Fri, May 10, 2013  1:02:49 PM
// Author: tomyeh
part of stream;

/**
 * RSP utilities.
 *
 * > They are used in the generated code of RSP pages.
 */
class Rsp {
  /** Converts the given value to a non-null string.
   * If the given value is not null, `toString` is called.
   * If null, an empty string is returned.
   */
  static String nns([v]) => v != null ? v.toString(): "";

  /** Converts the given value to a non-null [Future].
   */
  static Future nnf([v]) => v is Future ? v: new Future.value(v);

  /** Converts the given value to a non-null string with the given conditions.
   *
   * * [encode] - the encoding method. It can be `none` (output directly),
   *`xml` (for HTML/XML) and `query` (for query string).
   * If omitted, `xml` is assumed, i.e, < will be converted to &amp; and so on.
   *
   * * [maxlength]: limit the number of characters being output.
   * If non positive (default), the whole string will be output.
   * 
   * * [firstLine]: output only the first non-empty line (default: false).
   *
   * * [pre]: whether to replace whitespace with `&nbsp;` (default: false).
   * It is meaningful only if encode is `xml`.
   */
  static String nnx(value, {String encode, int maxlength: 0, bool firstLine: false,
    pre: false}) {
    String str = value != null ? value.toString(): "";
    if (firstLine) {
      for (int i = 0;;) {
        final j = str.indexOf('\n', i);
        if (j < 0) {
          str = str.substring(i);
          break;
        }
        if (j > i) {
          str = str.substring(i, j);
          break;
        }
        ++i;
      }
    }

    if (maxlength > 0 && maxlength > str.length)
      str = str.substring(0, maxlength) + "...";

    switch (encode) {
      case "none":
        break;
      case "query":
        str = Uri.encodeQueryComponent(str);
        break;
      default: //xml/html
        str = XmlUtil.encode(str, pre: pre);
        break;
    }
    return str;
  }

  /** Concatenates a path with a map of parameters.
   */
  static String cat(String uri, Map<String, dynamic> parameters) {
    if (parameters == null || parameters.isEmpty)
      return uri;

    int i = uri.indexOf('?');
    String query;
    if (i >= 0) {
      query = uri.substring(i);
      uri = uri.substring(0, i);
    }
    final query2 = HttpUtil.encodeQuery(parameters);
    return uri + (query == null ? "?query2": "$query&query2");
  }

  /** Serializes the given object into a JSON string by use of
   * [stringify](http://api.dartlang.org/docs/releases/latest/dart_json.html#stringify).
   */
  static String json(data) => Json.stringify(data).replaceAll("</script>", "<\\/script>");
    //it is possible that a string contains </script>
}
