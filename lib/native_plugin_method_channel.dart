import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native_plugin_platform_interface.dart';

/// An implementation of [NativePluginPlatform] that uses method channels.
class MethodChannelNativePlugin extends NativePluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('native_plugin');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<int> createPipContentView({
    String status = '',
    Uint8List? iconPng,
    String? videoTrackId,
  }) async {
    final viewId = await methodChannel.invokeMethod<int>(
      'createPipContentView',
      <String, dynamic>{
        'status': status,
        if (iconPng != null) 'iconPng': iconPng,
        if (videoTrackId != null && videoTrackId.isNotEmpty)
          'videoTrackId': videoTrackId,
      },
    );
    return viewId ?? 0;
  }

  @override
  Future<void> updatePipContentView({
    required int viewId,
    required String status,
  }) async {
    await methodChannel.invokeMethod<void>(
      'updatePipContentView',
      <String, dynamic>{
        'viewId': viewId,
        'status': status,
      },
    );
  }

  @override
  Future<void> disposePipContentView(int viewId) async {
    await methodChannel.invokeMethod<void>('disposePipContentView', viewId);
  }
}
