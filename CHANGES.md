#CHANGES

**0.8.1**

* Issue 44: The page tag supports the part attribute to include other dart files, and the dart attribute to embed code before the function

**0.8.0**

* Issue 42: Allow a Stream server to listen multiple addresses/ports and web sockets
* Issue 43: Allow to map WebSocket directly without invoking WebSocketTransformer explicitly
* Issue 41: Able to encode the build number into JS and/or CSS s.t. the browse will use the latest JS/CSS automatically

**0.7.6**

* API changed because of the deprecation of Path

**0.7.5**

* StreamServer.chunkedTransferEncoding supported for compressing the output with GZIP
* Issue 38: Unable to use the nested groups in route segments

**0.7.4**

* Issue 36: Change the spec of [:json] to generate a JSON object that can be parse as Dart object directly
* Issue 35: A tag for generating the dart script for development, while generating only JS in production
* HttpConnect.buffer is renamed to HttpConnect.stringBuffer, while HttpConnect.buffer reserved for bytes

**0.7.3**

* Issue 32: HttpConnect provides API to retrieve the information of the browser
* Issue 31: RSP supports last-modified as the time it has been compiled
* Issue 33: The expression tag ([= expr]) supports the encoding option
* Issue 34: Make the webapp directory optional

**0.7.2**

* Issue 28: Support the JSON tag for simplifying the rendering of a Dart object
* Issue 29: The homDir argument shall interpret the relative path against the root directory of the application

**0.7.1**

* HttpConnect.error has been removed. All errors shall be wired back Future.
* StreamServer.host can be String or InternetAddress, and the default is ANY_IP_V4.
* Issue 27: Able to configure Stream server to enforce the return of Future in every handler.

**0.7.0**

* Issue 16: Make include, forward and handler to return Future if there is any async task
* Issue 17: include and forward shall handle the query string
* Issue 24: llow RSP compiler receive a FilenameMapper function to map output files
* Issue 26: Support HttoConnect.redirect(uri) to redirect to another URI

*Upgrade Notes*

1. The request handler must return `Future` if it spawned an asynchronous task.
2. The request handler can't return a forwarding URI. Rather, it shall invoke and return `connect.forward(uri)` instead.
3. The request handler needs not to close the connection. It is done automatically.
4. RSP will import `dart:async` by default.
5. The request filter must return `Future`.
6. The `close`, `onClose` and `onError` methods of `HttpConnect` are removed. Chaining request handlers is straightforward: it is the same as chaining `Future` objects.

**0.6.2**

* Issue 11: Allow URI and filter mapping to be added dynamically

*Upgrade Note*

* The syntax of a tag has been changed from [tag] to [:tag]. The old syntax still works
but will be removed in the near future.

**0.6.1**

* Issue 7: Allow URI mapping to be pluggable
* Issue 8: URI mapping supports RESTful like mapping
* Issue 9: URI mapping allows to forward to another URI

**0.6.0**

* [page] introduces the partOf and import attributes
* [dart] is always generated inside the render function
* Issue 2: RSP files can be put in the client folder (i.e., not under the webapp folder)
* Issue 3: [page] partOf accepts a dart file and maintains it automatically
* Issue 4: Allow to mix expression ([=...]) with literal in tag attributes

**0.5.5**

* The composite view (aka., templating) is supported.
* The syntax of the include and forward tags are changed.
* The var tag is introduced.

**0.5.4**

* URL mapping supports grouping, such as /user/(name:[^/]*)
* StreamServer.run() is deprecated. Use start(), startSecure() or startOn() instead.
* Support the new Dart I/O.

**0.5.3**

* The filter mapping is supported.
* HttpConnect.then is removed. Use Future.catchError() instead.

**0.5.2**

* The error mapping takes the syntax of Map<code or exception, URI or function>.

**0.5.1**

* The comment tag is renamed to a pair of `[!--` and `--]`
