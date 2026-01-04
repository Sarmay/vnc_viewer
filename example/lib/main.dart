import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:vnc_viewer/vnc_viewer_handel.dart';
import 'package:vnc_viewer/vnc_viewer_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _vncViewerPlugin = VncViewerHandel();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await _vncViewerPlugin.getPlatformVersion() ??
              'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    print("platformVersion:$platformVersion");
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: AppPage());
  }
}

class AppPage extends StatelessWidget {
  TextEditingController _hostNameEditingController = new TextEditingController()
    ..text = "192.168.137.178";

  TextEditingController _portEditingController = new TextEditingController()
    ..text = "5900";

  TextEditingController _passwordEditingController = new TextEditingController()
    ..text = "Admin";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LibVncViewer example app')),
      body: Container(
        margin: EdgeInsets.all(10),
        child: Center(
          child: Column(
            children: [
              TextFormField(
                controller: _hostNameEditingController,
                decoration: const InputDecoration(hintText: 'host name'),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _portEditingController,
                decoration: const InputDecoration(hintText: 'port'),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordEditingController,
                decoration: const InputDecoration(hintText: 'password'),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              Text(""),
              CupertinoButton.filled(
                onPressed: () {
                  String hostName = _hostNameEditingController.text;
                  String port = _portEditingController.text;
                  String password = _passwordEditingController.text;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return Column(
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: VncViewerWidget(
                                hostName: hostName,
                                password: password,
                                port: int.parse(port),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
                child: const Text('open vnc viewer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
