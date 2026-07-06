import 'package:flutter/material.dart';

/// カメラ撮影画面(S06)のシャッターボタン。
///
/// 残り撮影枚数が0のときは操作不可(グレーアウト)にする(仕様書 5.2.3)。
class ShutterButton extends StatelessWidget {
  const ShutterButton({
    required this.remaining,
    required this.onPressed,
    super.key,
  });

  final int remaining;
  final VoidCallback onPressed;

  bool get _isEnabled => remaining > 0;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _isEnabled ? onPressed : null,
      backgroundColor: _isEnabled
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).disabledColor,
      child: const Icon(Icons.camera_alt),
    );
  }
}
