import 'dart:typed_data';

import 'native_plugin_platform_interface.dart';

class NativePlugin {
  Future<String?> getPlatformVersion() {
    return NativePluginPlatform.instance.getPlatformVersion();
  }

  Future<int> createPipContentView({
    String status = '',
    Uint8List? iconPng,
    String? videoTrackId,
  }) {
    return NativePluginPlatform.instance.createPipContentView(
      status: status,
      iconPng: iconPng,
      videoTrackId: videoTrackId,
    );
  }

  Future<void> updatePipContentView({
    required int viewId,
    required String status,
  }) {
    return NativePluginPlatform.instance.updatePipContentView(
      viewId: viewId,
      status: status,
    );
  }

  Future<void> disposePipContentView(int viewId) {
    return NativePluginPlatform.instance.disposePipContentView(viewId);
  }
}
