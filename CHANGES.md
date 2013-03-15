#CHANGES

**0.6.0**

* [page] introduces the partOf and imports attributes
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
