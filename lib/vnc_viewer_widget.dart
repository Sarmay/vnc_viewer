import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vnc_viewer/vnc_viewer_handel.dart';

class VncViewerWidget extends StatefulWidget {
  final String hostName;
  final String password;
  final int port;
  final Function(int clientId)? onStart;
  final Function(int clientId)? onClose;
  final VoidCallback? onImageResize;
  final Function(String msg)? onError;

  const VncViewerWidget({
    super.key,
    required this.hostName,
    required this.password,
    this.port = 5900,
    this.onStart,
    this.onClose,
    this.onError,
    this.onImageResize,
  });

  @override
  State<StatefulWidget> createState() => _VncViewerWidgetState();
}

class _VncViewerWidgetState extends State<VncViewerWidget>
    with WidgetsBindingObserver {
  static const EventChannel _channel = EventChannel(
    'libvncviewer_flutter_eventchannel',
  );

  StreamSubscription? _streamSubscription;

  final StreamController<int> _streamController = StreamController();

  final _libvncviewerFlutterPlugin = VncViewerHandel();

  int _imageWidth = 0;

  int _imageHeight = 0;

  double _width = 0;

  double _height = 0;

  int _clientId = 0;

  int _textureId = -1;

  double _scale = 1.0;

  final GlobalKey _vncViewKey = GlobalKey();

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BuildContext curContext = context;
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      _clientId = await _libvncviewerFlutterPlugin.initVncClient(
            widget.hostName,
            widget.port,
            widget.password,
          ) ??
          0;
      if (_clientId != 0) {
        _streamSubscription =
            _channel.receiveBroadcastStream({"clientId": _clientId}).listen(
          (dynamic event) {
            Map data = event;
            String flag = data["flag"];
            if (flag == "imageResize") {
              _imageWidth = data["width"];
              _imageHeight = data["height"];
              _textureId = data["textureId"];
              _streamController.add(1);
              if (widget.onImageResize != null) {
                widget.onImageResize!();
              }
            }
            if (flag == "onReady") {
              _libvncviewerFlutterPlugin.startVncClient(_clientId);
              if (widget.onStart != null) {
                widget.onStart!(_clientId);
              }
            }
            if (flag == "onClose") {
              if (widget.onClose != null) {
                widget.onClose!(_clientId);
              }
            }
            if (flag == "onError") {
              String errMsg = data["msg"];
              if (widget.onError != null) {
                widget.onError!(errMsg);
              } else {
                if (curContext.mounted) {
                  showCupertinoModalPopup<void>(
                    context: curContext,
                    builder: (BuildContext context) {
                      return CupertinoAlertDialog(
                        title: const Text('错误提示'),
                        content: Text(errMsg),
                        actions: <CupertinoDialogAction>[
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            child: const Text('关闭'),
                          ),
                        ],
                      );
                    },
                  );
                }
              }
            }
          },
          onError: (dynamic error) {
            print('Received error: ${error.message}');
            if (widget.onError != null) {
              widget.onError!(error.message);
            }
          },
          cancelOnError: true,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      initialData: _textureId,
      stream: _streamController.stream,
      builder: (context, async) {
        _width = MediaQuery.of(context).size.width;
        //状态栏高度
        double statusBarHeight = MediaQueryData.fromView(window).padding.top;
        _height = MediaQuery.of(context).size.height - statusBarHeight;
        Widget appBar = Container();
        Widget content = Container();
        if (async.data == -1) {
          content = GestureDetector(
            onTap: () {
              _streamController.add(-1);
              if (_timer != null) {
                _timer!.cancel();
              }
              _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
                _timer!.cancel();
                _streamController.add(-1);
              });
            },
            child: Container(
              color: Colors.white,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  CupertinoActivityIndicator(radius: 15),
                  SizedBox(height: 10),
                  Text(
                    '正在连接',
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ],
              ),
            ),
          );
        } else {
          double horizontalScale = _width / _imageWidth;
          double verticalScale = _height / _imageHeight;
          // 选择较小的缩放比例，以确保图片可以完全显示在屏幕上
          _scale =
              horizontalScale < verticalScale ? horizontalScale : verticalScale;
          _width = _imageWidth * _scale;
          _height = _imageHeight * _scale;
          content = Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            color: Colors.white,
            child: GestureDetector(
              onTap: () {
                _streamController.add(1);
              },
              child: InteractiveViewer(
                scaleEnabled: true,
                child: Center(
                  child: SizedBox(
                    width: _width,
                    height: _height,
                    child: Texture(
                      textureId: _textureId,
                      key: _vncViewKey,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return Stack(
          children: [
            Positioned(top: 0, left: 0, right: 0, bottom: 0, child: content),
            Positioned(top: 0, left: 0, child: appBar),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    _streamSubscription!.cancel();
    _libvncviewerFlutterPlugin.closeVncClient(_clientId);
    WidgetsBinding.instance.removeObserver(this);
    if (widget.onClose != null) {
      widget.onClose!(_clientId);
    }
  }
}
