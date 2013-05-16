//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Fri, May 10, 2013  1:02:49 PM
// Author: tomyeh
part of stream;

/**
 * RSP utilities.
 *
 * > They are used in the generated code of RSP pages.
 */
class RSP {
  /** Converts the given value to a non-null string.
   * If the given value is not null, `toString` is called.
   * If null, an empty string is returned.
   */
  static String nns([v]) => v != null ? v.toString(): "";

  /** Converts the given value to a non-null [Future].
   */
  static Future nnf([v]) => v is Future ? v: new Future.value(v);

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

  ///JSON strigify the given Dart object
  static String json(data) => Json.stringify(data);
}
