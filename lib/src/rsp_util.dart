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
  /// Tests if the given [value] can be used as HTTP header's value
  static bool isHeaderValueValid(String value) {
    for (final byte in value.codeUnits)
      if (!_isHeaderValueValidCC(byte))
        return false;
    return true;
  }
  static bool _isHeaderValueValidCC(int byte)
  => (byte > 31 && byte < 128) || byte == $tab;

  /** Initializes a RSP page.
   * It is used by generated RSP dart code. You don't need to invoke it.
   * 
   * It returns false if the content shall not be generated.
   * The caller shall stop immediately if this method returns false.
   *
   * * [contentType] - ignored if null or empty.
   */
  static bool init(HttpConnect connect, String? contentType,
    {DateTime? lastModified, String? etag}) {
    if (!connect.isIncluded) {
      final response = connect.response;
      final headers = response.headers;
      if (contentType != null && contentType.isNotEmpty)
        headers.contentType = parseContentType(contentType);

      bool isPreconditionFailed = false;
      if (etag != null || lastModified != null) {
        if (!checkIfHeaders(connect, lastModified, etag))
          return false;

        isPreconditionFailed = response.statusCode == HttpStatus.preconditionFailed;
            //Set by checkIfHeaders (see also Issue 59)
        if (isPreconditionFailed || response.statusCode < HttpStatus.badRequest) {
          if (lastModified != null)
            headers.set(HttpHeaders.lastModifiedHeader, lastModified);
          if (etag != null)
            headers.set(HttpHeaders.etagHeader, etag);
        }

      }

      if (connect.request.method == "HEAD" || isPreconditionFailed) 
        return false; //no more processing
    }
    return true;
  }

  /** Converts the given value to a non-null string.
   * If the given value is not null, `toString` is called.
   * If null, an empty string is returned.
   */
  static String nns([v]) => v != null ? v.toString(): "";

  /** Converts the given value to a non-null string with the given conditions.
   *
   * * [encode] - the encoding method. It can be `none` (output directly),
   * 'json', `xml` (for HTML/XML) and `query` (for query string).
   * If omitted, `xml` is assumed, i.e, < will be converted to &amp; and so on.
   *
   * * [maxLength]: limit the number of characters being output.
   * If non positive (default), the whole string will be output.
   * 
   * * [firstLine]: output only the first non-empty line (default: false).
   *
   * * [pre]: whether to replace whitespace with `&nbsp;` (default: false).
   * It is meaningful only if encode is `xml`.
   */
  static String nnx(value, {String? encode, int maxLength = 0,
    bool firstLine = false, bool pre = false}) {
    String str = encode == "json" ? json(value):
        value != null ? value.toString(): "";
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

    if (maxLength > 0 && maxLength > str.length)
      str = maxLength < 3 ? "...": str.substring(0, maxLength - 3) + "...";

    switch (encode) {
      case "none":
      case "json":
        break;
      case "query":
        str = Uri.encodeQueryComponent(str);
        break;
      default: //xml/html
        str = XmlUtil.encodeNS(str, pre: pre);
        break;
    }
    return str;
  }

  /** Concatenates a path with a map of parameters.
   */
  static String cat(String uri, Map<String, dynamic>? parameters) {
    if (parameters == null || parameters.isEmpty)
      return uri;

    int i = uri.indexOf('?');
    String? query;
    if (i >= 0) {
      query = uri.substring(i);
      uri = uri.substring(0, i);
    }
    final query2 = HttpUtil.encodeQuery(parameters);
    return uri + (query == null ? "?$query2": "$query&$query2");
  }

  /// Serializes the given object into a JSON string by use of `jsonEncode`.
  static String json(data) => cvt.json.encode(data).replaceAll(_scriptPtn, r"<\/");
  static final _scriptPtn = RegExp(r"</(?=script>)", caseSensitive: false);
    //it is possible that a string contains </script>
}
