import 'dart:async';
import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/widgets.dart';

/// テスト用の`CameraPlatform`実装。
///
/// 実機のカメラプラグインを使わずに`CameraController`の初期化・撮影を
/// 完了させ、`takePicture()`が返す画像データを差し替えられるようにする。
class FakeCameraPlatform extends CameraPlatform {
  FakeCameraPlatform({
    Uint8List? capturedImageBytes,
    this.createCameraError,
  }) : capturedImageBytes = capturedImageBytes ?? Uint8List.fromList([1, 2, 3]);

  /// `takePicture()`が返す画像データ。
  Uint8List capturedImageBytes;

  /// 設定されている間、`createCameraWithSettings()`はこの値を投げる
  /// (カメラ初期化失敗・再試行のシナリオをテストするために使う)。
  Exception? createCameraError;

  /// `createCameraWithSettings()`が呼ばれた回数(再試行の連打ガードなど、
  /// カメラ初期化が意図した回数だけ行われることを検証するために使う)。
  int createCameraCallCount = 0;

  /// 設定されている間、`dispose()`はこのFutureが完了するまで待つ
  /// (再試行の連打ガードのテストで、disposeの完了を意図的に保留し、
  /// 2回目のタップが1回目の処理中に割り込むケースを再現するために使う)。
  Future<void>? disposeGate;

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
    createCameraCallCount++;
    final error = createCameraError;
    if (error != null) {
      throw error;
    }
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
  Future<void> dispose(int cameraId) async {
    final gate = disposeGate;
    if (gate != null) {
      await gate;
    }
  }
}
