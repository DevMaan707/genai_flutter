import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'genai_flutter_platform_interface.dart';

/// An implementation of [GenaiFlutterPlatform] that uses method channels.
class MethodChannelGenaiFlutter extends GenaiFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('genai_flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
