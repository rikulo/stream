#CHANGES

**0.5.5**

* The composite view (aka., templating) is supported.
* The syntax of the include and forward tags are simplified.
* The var tag is introduced.

**0.5.4**

* URL mapping supports grouping, such as /user/(name:[^/]*)
* StreamServer.run() is deprecated. Use start(), startSecure() or startOn() instead.
* Support the new Dart I/O.

**0.5.3**

* The filter mapping is supported.
* HttpConnect.then is removed. Use Future.catchError() instead.

**0.5.2**

* The error mapping takes the syntax of Map<code or exception, uri or function>.

**0.5.1**

* The comment tag is renamed to a pair of `[!--` and `--]`
