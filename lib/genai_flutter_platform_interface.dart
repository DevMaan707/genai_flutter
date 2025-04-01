import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'genai_flutter_method_channel.dart';

abstract class GenaiFlutterPlatform extends PlatformInterface {
  /// Constructs a GenaiFlutterPlatform.
  GenaiFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static GenaiFlutterPlatform _instance = MethodChannelGenaiFlutter();

  /// The default instance of [GenaiFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelGenaiFlutter].
  static GenaiFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [GenaiFlutterPlatform] when
  /// they register themselves.
  static set instance(GenaiFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
