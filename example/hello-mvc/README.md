#Hello MVC

This sample demonstrates how to apply the MVC design pattern in your web application.

It is demonstrated by displaying the content of a directory.

> It is for demonstration only. It is generally not safe to display the content of the server's file system.

##Model

In this application, the model is a list of instances of `FileInfo`. Each of them provides the information about a file or a directory:

    class FileInfo {
      final String name;
      final bool isDirectory;

      FileInfo(this.name, this.isDirectory);
    }

##View

The view is implemented as a RSP page: [listView.rsp.html](https://github.com/rikulo/stream/blob/master/example/hello-mvc/webapp/listView.rsp.html). It will be compiled as a closure called `listView`, which will be called by the controller, as described below, to display the result. Here is a snippet of it.

    <table border="1px" cellspacing="0">
      <tr>
        <th>Type</th>
        <th>Name</th>
      </tr>
    [for info in infos]
      <tr>
        <td><img src="[=info.isDirectory ? 'file.png': 'directory.png']"/></td>
        <td>[=info.name]</td>
      </tr>
    [/for]
    </table>


##Control

The role of the control, `helloMVC`, is to prepare the model for rendering. As shown [here](https://github.com/rikulo/stream/blob/master/example/hello-mvc/webapp/main.dart), the preparation is done asynchronously. It is very important for scalability.

    Future helloMVC(HttpConnect connect) {
      //1. prepare the model
      final curdir = Directory.current;
      List<FileInfo> list = [];
      return curdir.list().listen((fse) {
        list.add(new FileInfo(fse.path, fse is Directory));
      }).asFuture().then((_) {
        //2. forward to the view
        return listView(connect, path: curdir.path, infos: list);
      });
    }
