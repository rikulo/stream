#Hello Static Resources

This sample demonstrates how to use static resources in your web application.

##File Structure

###The `webapp` Directory

Each web application shall contains a `webapp` directory. The directory contains the server-side code and resources that are not visible to the clients.

Under `webapp`, you need to put at least one Dart file containing the `main` function. In the `main` function, you can start the Stream server as follows:

    import "package:stream/stream.dart";

    void main() {
      new StreamServer().start();
    }

###Other Directories

Files under other directories are accessible from the clients, unless the URI is mapped to an handler. In this example, we put `index.html`, CSS and ICO file at the root directory. You can structure it the way you'd like.

##Launch the Application

The `main` function is in `webapp/main.dart`, so you can start the web server by executing the following statement:

    dart webapp/main.dart

> You don't have to change the directory to the web application. Stream will detect the root directory automatically by assuming the parent directory of `webapp` is the root directory.

###Visit the Application

After launched, you can visit [http://localhost:8080](http://localhost:8080) with your web browser.
