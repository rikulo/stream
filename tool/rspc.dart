#!/usr/bin/env dart

//RSP (Rikulo Stream Page) Compiler
//
//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Mon, Jan 14, 2013  2:08:32 PM
// Author: tomyeh
library rspc;

import "package:stream/rspc.dart" as rspc;

void main(List<String> arguments) {
  /* initialize your custom RSP tags here
   * example:
    rspc.tags["m"] = new rspc.SimpleTag("m",
    (rspc.TagContext tc, String id, Map<String, String> args) {
      if (id == null)
        throw new ArgumentError("required");
      tc.write("\n${tc.pre}response.write(m(connect, $id");
      if (args != null && !args.isEmpty) {
        tc.write(", ");
        rspc.outMap(tc, args);
      }
      tc.writeln("));");
    });
  */

  rspc.main(arguments);
}
