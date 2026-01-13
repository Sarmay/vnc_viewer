import 'package:flutter/material.dart';
import 'package:vnc_viewer/vnc_viewer_handel.dart';
import 'package:vnc_viewer/vnc_viewer_widget.dart';

class ExampleViewer extends StatefulWidget {
  const ExampleViewer({
    super.key,
    required this.hostName,
    required this.password,
    required this.port,
  });

  final String hostName;
  final String password;
  final String port;

  @override
  State<ExampleViewer> createState() => _ExampleViewerState();
}

class _ExampleViewerState extends State<ExampleViewer> {
  final VncViewerHandel _vncViewerPlugin = VncViewerHandel();
  int? _clientId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: VncViewerWidget(
              hostName: widget.hostName,
              password: widget.password,
              port: int.parse(widget.port),
              onClose: (int clientId) {
                print("外部:关闭 $clientId");
              },
              onStart: (int clientId) {
                print("外部:打开 $clientId");
                _clientId = clientId;
                if (mounted) {
                  setState(() {});
                }
              },
              onError: (e) {
                print("外部错误:$e");
              },
              onImageResize: () {
                print("外部:onImageResize");
              },
            ),
          ),
          MaterialButton(
            onPressed: () async {
              print("发送消息");
              if (_clientId != null) {
                await forceRebootVncServer(_clientId!);
              } else {
                print("未获取到clientId");
              }
            },
            color: Colors.green,
            child: const Text("重启服务器"),
          )
        ],
      ),
    );
  }

  /// 核心方法：发送root密码kissme并执行reboot重启
  Future<void> rebootVncServer(int clientId) async {
    try {
      // 步骤1：先发送打开终端的快捷键（Ctrl+Alt+T，通用终端快捷键）
      await sendCombinationKey(clientId, [0xffe3, 0xffe9, 0x74], delay: 1500);

      // 步骤2：输入su -l root（切换到root用户）
      await sendSingleKey(clientId, VncKeyCodes.keyS); // s
      await sendSingleKey(clientId, VncKeyCodes.keyU); // u
      await sendSingleKey(clientId, VncKeyCodes.keySpace); // 空格
      await sendSingleKey(clientId, VncKeyCodes.keyDash); // -
      await sendSingleKey(clientId, VncKeyCodes.keyL); // l
      await sendSingleKey(clientId, VncKeyCodes.keySpace); // 空格
      await sendSingleKey(clientId, VncKeyCodes.keyR); // r
      await sendSingleKey(clientId, VncKeyCodes.keyO); // o
      await sendSingleKey(clientId, VncKeyCodes.keyO); // o
      await sendSingleKey(clientId, VncKeyCodes.keyT); // t
      await sendSingleKey(clientId, VncKeyCodes.keyEnter, delay: 1500); // 回车

      // 步骤3：输入root密码kissme
      await sendSingleKey(clientId, VncKeyCodes.keyK); // k
      await sendSingleKey(clientId, VncKeyCodes.keyI); // i
      await sendSingleKey(clientId, VncKeyCodes.keyS); // s
      await sendSingleKey(clientId, VncKeyCodes.keyS); // s
      await sendSingleKey(clientId, VncKeyCodes.keyM); // m
      await sendSingleKey(clientId, VncKeyCodes.keyE); // e
      await sendSingleKey(clientId, VncKeyCodes.keyEnter,
          delay: 2000); // 回车（等待切换root）

      // 步骤4：输入reboot并执行
      await sendSingleKey(clientId, VncKeyCodes.keyR); // r
      await sendSingleKey(clientId, VncKeyCodes.keyE); // e
      await sendSingleKey(clientId, VncKeyCodes.keyB); // b
      await sendSingleKey(clientId, VncKeyCodes.keyO); // o
      await sendSingleKey(clientId, VncKeyCodes.keyO); // o
      await sendSingleKey(clientId, VncKeyCodes.keyT); // t
      await sendSingleKey(clientId, VncKeyCodes.keyEnter); // 回车重启
    } catch (e) {
      print('重启命令发送失败：$e');
    }
  }

  /// 应急方案：Magic SysRq强制重启（无需TTY/终端）
  Future<void> forceRebootVncServer(int clientId) async {
    try {
      // SysRq键Code（PrintScreen）
      const int keySysRq = 0xff63;
      // Alt键Code
      const int keyAlt = 0xffe9;

      // 步骤1：按住Alt + SysRq（保持2秒）
      _vncViewerPlugin.sendKey(clientId, keyAlt, true);
      _vncViewerPlugin.sendKey(clientId, keySysRq, true);
      await Future.delayed(const Duration(milliseconds: 2000));
      _vncViewerPlugin.sendKey(clientId, keySysRq, false);

      // 步骤2：依次发送R → E → I → S → U → B（每个键间隔1秒）
      List<int> sysRqKeys = [0x72, 0x65, 0x69, 0x73, 0x75, 0x62]; // R,E,I,S,U,B
      for (int key in sysRqKeys) {
        await sendSingleKey(clientId, key, delay: 1000);
      }

      // 步骤3：松开Alt键
      _vncViewerPlugin.sendKey(clientId, keyAlt, false);
    } catch (e) {
      print('强制重启失败：$e');
    }
  }

  /// 发送单个按键（按下+松开），添加延迟保证识别
  Future<void> sendSingleKey(int clientId, int keyCode,
      {int delay = 300}) async {
    // 按下按键
    _vncViewerPlugin.sendKey(clientId, keyCode, true);
    await Future.delayed(const Duration(milliseconds: 80)); // 延长按下延迟
    // 松开按键
    _vncViewerPlugin.sendKey(clientId, keyCode, false);
    await Future.delayed(Duration(milliseconds: delay));
  }

  /// 发送组合键（如Ctrl+Alt+F1）
  /// [keys] 组合键的Code列表
  /// [delay] 组合键按下后延迟时间
  Future<void> sendCombinationKey(int clientId, List<int> keys,
      {int delay = 1500}) async {
    // 1. 先按下所有组合键（确保同时按住）
    for (int key in keys) {
      _vncViewerPlugin.sendKey(clientId, key, true);
      await Future.delayed(const Duration(milliseconds: 100)); // 延长按下间隔
    }

    // 2. 保持按住500ms，确保系统识别组合键
    await Future.delayed(const Duration(milliseconds: 500));

    // 3. 逆序松开所有键（避免按键卡住）
    for (int key in keys.reversed) {
      _vncViewerPlugin.sendKey(clientId, key, false);
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 4. 等待组合键生效
    await Future.delayed(Duration(milliseconds: delay));
  }
}

// VNC按键Code常量（X11标准，Linux TTY通用）
class VncKeyCodes {
  // 字母键（kissme）
  static const int keyK = 0x6b; // k
  static const int keyI = 0x69; // i
  static const int keyS = 0x73; // s
  static const int keyM = 0x6d; // m
  static const int keyE = 0x65; // e

  // 命令键（reboot/su）
  static const int keyR = 0x72; // r
  static const int keyB = 0x62; // b
  static const int keyO = 0x6f; // o
  static const int keyT = 0x74; // t
  static const int keyU = 0x75; // u

  // 功能键
  static const int keyEnter = 0xff0d; // 回车
  static const int keySpace = 0x20; // 空格
  static const int keyDash = 0x2d; // 减号（-）
  static const int keyL = 0x6c; // l（su -l root中的l）
}
