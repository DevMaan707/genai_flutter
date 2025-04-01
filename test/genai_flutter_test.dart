import 'package:flutter_test/flutter_test.dart';
import 'package:genai_flutter/genai_flutter.dart';
import 'package:genai_flutter/genai_flutter_platform_interface.dart';
import 'package:genai_flutter/genai_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockGenaiFlutterPlatform
    with MockPlatformInterfaceMixin
    implements GenaiFlutterPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final GenaiFlutterPlatform initialPlatform = GenaiFlutterPlatform.instance;

  test('$MethodChannelGenaiFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelGenaiFlutter>());
  });

  test('getPlatformVersion', () async {
    GenaiFlutter genaiFlutterPlugin = GenaiFlutter();
    MockGenaiFlutterPlatform fakePlatform = MockGenaiFlutterPlatform();
    GenaiFlutterPlatform.instance = fakePlatform;

    expect(await genaiFlutterPlugin.getPlatformVersion(), '42');
  });
}
