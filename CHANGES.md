#CHANGES

**0.7.0**

* Issue 16: Make include, forward and handler to return Future if there is any async task
* Issue 17: include and forward shall handle the query string
* Issue 24: llow RSP compiler receive a FilenameMapper function to map output files

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
