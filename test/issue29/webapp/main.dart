//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Sun, May 19, 2013  1:51:09 PM
// Author: tomyeh

import "package:stream/stream.dart";

void main() {
  new StreamServer(homeDir: "static").start();
}
