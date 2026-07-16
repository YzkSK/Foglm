import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/camera/camera_screen.dart';

const _back = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 0,
);
const _front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 0,
);
const _external = CameraDescription(
  name: 'external',
  lensDirection: CameraLensDirection.external,
  sensorOrientation: 0,
);

void main() {
  group('selectPreferredCamera', () {
    test('selects the back camera when it is listed first', () {
      expect(selectPreferredCamera([_back, _front]), _back);
    });

    test('selects the back camera even when it is not listed first', () {
      expect(selectPreferredCamera([_front, _external, _back]), _back);
    });

    test(
      'falls back to the first camera when no back camera is available',
      () {
        expect(selectPreferredCamera([_front, _external]), _front);
      },
    );

    test('returns the only camera when there is just one', () {
      expect(selectPreferredCamera([_external]), _external);
    });
  });
}
