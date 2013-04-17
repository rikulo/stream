//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Sat, Apr 13, 2013  9:24:03 PM
// Author: tomyeh

List<Map> _times = [];

void _mark(String what) {
  _times.add({"what": what, "time": new DateTime.now()});
}
void _check(RegExp regex, String value, bool matched) {
  if (matched != regex.hasMatch(value))
    throw "$value shall " + (matched ? "": "not ") + "match";
}

void main() {
  print("Test the performance of using single regex v.s. multiple");

  final loop = 100000;
  final List<RegExp> patterns = [];
  final buf = new StringBuffer()..write("^(");
  for (final p in ["/forward", "/include", "/search",
    "/(g[a-z]*p)/(ma[a-z]*)", "/old-link(.*)",
    "/new-link.*", "/500", "/recoverable-error", "/log5", "/longop",
    "/user/([^/])*/"]) {
    if (!patterns.isEmpty)
      buf.write('|');
      buf.write("$p");
//    buf.write("($p)");
    patterns.add(new RegExp("^$p\$"));
  }
  final group = new RegExp((buf..write(")\$")).toString());

  _check(group, '/old-link/abc', true);
  _check(group, '/group/matching', true);
  _check(group, '/wont/match', false);

  String uri = "/wont/match";
  _mark("started");

  for (int i = loop; --i >= 0;)
    group.hasMatch(uri);
  _mark("group matching");

  for (int i = loop; --i >= 0;) {
    for (int j = 0; j < patterns.length; ++j)
      if (patterns[j].hasMatch(uri))
        break;
  }
  _mark("one-by-one");

  for (int i = 1; i < _times.length; ++i)
    print("${_times[i]['what']}: ${_times[i]['time'].millisecondsSinceEpoch - _times[i - 1]['time'].millisecondsSinceEpoch}");

  final match = group.firstMatch("/group/matching");
  for (int gc = match.groupCount, i = 0; i < gc; ++i)
    print("$i: ${match.group(i)}");
}
