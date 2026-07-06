import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/camera/remaining_shots_provider.dart';
import 'package:foglm/features/camera/widgets/shutter_button.dart';

/// カメラ撮影画面(S06)。
///
/// 撮影の残り枚数を表示し、上限に達した場合はシャッターボタンを
/// 操作不可にする(仕様書 4.1 S06 / 5.2.3)。
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _controller;
  late final Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException(
        'noCameraAvailable',
        '利用可能なカメラが見つかりません',
      );
    }
    final controller = CameraController(cameras.first, ResolutionPreset.high);
    _controller = controller;
    await controller.initialize();
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  void _onShutterPressed() {
    ref.read(remainingShotsProvider.notifier).decrement();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = ref.watch(remainingShotsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || _controller == null) {
            return const Center(
              child: Text(
                'カメラを利用できません',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(_controller!),
              Positioned(
                top: 48,
                right: 24,
                child: _RemainingShotsBadge(remaining: remaining),
              ),
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: ShutterButton(
                    remaining: remaining,
                    onPressed: _onShutterPressed,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RemainingShotsBadge extends StatelessWidget {
  const _RemainingShotsBadge({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '残り $remaining 枚',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
