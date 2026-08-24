//Copyright (C) 2026 Potix Corporation. All Rights Reserved.
import "dart:async";
import "dart:convert";
import "dart:io";

import "package:test/test.dart";
import "package:stream/stream.dart";

/// Sends a raw request line (so encoded bytes like `%2f` reach the server
/// unmodified) and returns the full response text.
Future<String> _rawGet(int port, String rawPath) async {
  final sock = await Socket.connect(InternetAddress.loopbackIPv4, port);
  sock.write("GET $rawPath HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n");
  final bytes = <int>[];
  await sock.forEach(bytes.addAll);
  sock.destroy(); //release the half-open socket so the VM can exit
  return utf8.decode(bytes, allowMalformed: true);
}

int _status(String resp) => int.parse(resp.split("\r\n").first.split(" ")[1]);

void _writeRoot(Directory root) {
  File("${root.path}/ok.html").writeAsStringSync("PUBLIC_OK");
  File("${root.path}/index.rsp").writeAsStringSync("RSP_SOURCE_SECRET");
  Directory("${root.path}/webapp").createSync();
  File("${root.path}/webapp/main.dart").writeAsStringSync("WEBAPP_SECRET");
}

void main() {
  group("StreamServer access guards", () {
    late Directory root;
    late StreamServer server;
    late int port;

    setUp(() async {
      root = Directory.systemTemp.createTempSync("stream_sec");
      _writeRoot(root);
      server = StreamServer(homeDir: root.path)
        // direct loader calls -- exercise FileLoader's defense-in-depth backstop
        ..map("/direct-rsp",
            (HttpConnect c) => c.server.resourceLoader.load(c, "/index.rsp"))
        ..map("/direct-webapp",
            (HttpConnect c) => c.server.resourceLoader.load(c, "/webapp/main.dart"));
      final ch =
          await server.start(address: InternetAddress.loopbackIPv4, port: 0);
      port = ch.port;
    });

    tearDown(() async {
      await server.stop();
      root.deleteSync(recursive: true);
    });

    test("serves a normal static file", () async {
      final resp = await _rawGet(port, "/ok.html");
      expect(_status(resp), 200);
      expect(resp, contains("PUBLIC_OK"));
    });

    group("protectRSP", () {
      test("blocks .rsp source with 404", () async {
        expect(_status(await _rawGet(port, "/index.rsp")), 404);
      });
      test("backstop blocks a direct loader call to .rsp", () async {
        final resp = await _rawGet(port, "/direct-rsp");
        expect(_status(resp), 404);
        expect(resp, isNot(contains("RSP_SOURCE_SECRET")));
      });
    });

    group("encoded path separators", () {
      test("rejects %2f with 400 and no leak", () async {
        final resp = await _rawGet(port, "/index.rsp%2f");
        expect(_status(resp), 400);
        expect(resp, isNot(contains("RSP_SOURCE_SECRET")));
      });
      test("rejects uppercase %2F with 400", () async {
        expect(_status(await _rawGet(port, "/webapp%2Fmain.dart")), 400);
      });
      test("rejects %5c (backslash) with 400", () async {
        expect(_status(await _rawGet(port, "/a%5cb")), 400);
      });
      test("allows %2f inside the query string", () async {
        expect(_status(await _rawGet(port, "/ok.html?x=a%2fb")), 200);
      });
    });

    group("webapp source directory", () {
      test("blocks /webapp with 403", () async {
        expect(_status(await _rawGet(port, "/webapp/main.dart")), 403);
      });
      test("blocks /webapp case-insensitively", () async {
        final resp = await _rawGet(port, "/WebApp/main.dart");
        expect(_status(resp), 403);
        expect(resp, isNot(contains("WEBAPP_SECRET")));
      });
      test("backstop blocks a direct loader call to webapp", () async {
        final resp = await _rawGet(port, "/direct-webapp");
        expect(_status(resp), 404);
        expect(resp, isNot(contains("WEBAPP_SECRET")));
      });
    });
  });

  group("protectRSP: false opts out (and is honored by the loader)", () {
    late Directory root;
    late StreamServer server;
    late int port;

    setUp(() async {
      root = Directory.systemTemp.createTempSync("stream_sec_off");
      _writeRoot(root);
      server = StreamServer.router(DefaultRouter(protectRSP: false),
          homeDir: root.path);
      final ch =
          await server.start(address: InternetAddress.loopbackIPv4, port: 0);
      port = ch.port;
    });

    tearDown(() async {
      await server.stop();
      root.deleteSync(recursive: true);
    });

    test("serves .rsp source when protection is disabled", () async {
      final resp = await _rawGet(port, "/index.rsp");
      expect(_status(resp), 200);
      expect(resp, contains("RSP_SOURCE_SECRET"));
    });

    test("still blocks the webapp directory (unconditional)", () async {
      expect(_status(await _rawGet(port, "/webapp/main.dart")), 403);
    });
  });
}
