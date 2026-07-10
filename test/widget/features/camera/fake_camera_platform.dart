import 'dart:async';
import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/widgets.dart';

/// テスト用の`CameraPlatform`実装。
///
/// 実機のカメラプラグインを使わずに`CameraController`の初期化・撮影を
/// 完了させ、`takePicture()`が返す画像データを差し替えられるようにする。
class FakeCameraPlatform extends CameraPlatform {
  FakeCameraPlatform({Uint8List? capturedImageBytes})
    : capturedImageBytes = capturedImageBytes ?? Uint8List.fromList([1, 2, 3]);

  /// `takePicture()`が返す画像データ。
  Uint8List capturedImageBytes;

  @override
  Future<List<CameraDescription>> availableCameras() async {
    return const [
      CameraDescription(
        name: 'fake',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 0,
      ),
    ];
  }

  @override
  Future<int> createCameraWithSettings(
    CameraDescription description,
    MediaSettings? settings,
  ) async {
    return 1;
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) {
    return Stream.value(
      const CameraInitializedEvent(
        1,
        1920,
        1080,
        ExposureMode.auto,
        false,
        FocusMode.auto,
        false,
      ),
    );
  }

  // CameraControllerはonCameraError(...).first を待ち受けるため、
  // Stream.empty()を返すと「イベントを1件も出さずに完了したストリーム」
  // 扱いとなり`.first`がStateErrorを投げてしまう。エラーが起きない
  // フェイクとしては、決して完了しないストリームを返す必要がある。
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) =>
      StreamController<CameraErrorEvent>().stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      StreamController<DeviceOrientationChangedEvent>().stream;

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}

  @override
  Widget buildPreview(int cameraId) {
    return const SizedBox.expand();
  }

  @override
  Future<XFile> takePicture(int cameraId) async {
    return XFile.fromData(capturedImageBytes, mimeType: 'image/jpeg');
  }

  @override
  Future<void> dispose(int cameraId) async {}
}
