import 'package:vnc_viewer/vnc_viewer_platform_interface.dart';

class VncViewerHandel {
  Future<String?> getPlatformVersion() {
    return VncViewerPlatform.instance.getPlatformVersion();
  }

  Future<int?> initVncClient(String hostName, int port, String password) {
    return VncViewerPlatform.instance
        .initVncClient(hostName, port, password);
  }

  void closeVncClient(int clientId) {
    return VncViewerPlatform.instance.closeVncClient(clientId);
  }

  void startVncClient(int clientId) {
    return VncViewerPlatform.instance.startVncClient(clientId);
  }

  void sendPointer(int clientId, int x, int y, int mask) {
    return VncViewerPlatform.instance
        .sendPointer(clientId, x, y, mask);
  }

  void sendKey(int clientId, int key, bool down) {
    return VncViewerPlatform.instance.sendKey(clientId, key, down);
  }
}
