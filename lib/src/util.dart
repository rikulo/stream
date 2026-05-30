//Copyright (C) 2026 Potix Corporation. All Rights Reserved.
//Internal helpers shared between the `stream` and `stream_plugin` libraries.
//Kept under src/ and never exported, so nothing here is part of the public API.

///Matches the server-side `webapp` source directory (or any file within it),
///which must never be served to the client. Case-insensitive so `/WebApp/...`
///can't reach it on a case-insensitive filesystem.
final reWebapp = RegExp(r'^/webapp(?:/|$)', caseSensitive: false);
