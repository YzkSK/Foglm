import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/camera/application/upload_photo_controller.dart';
import 'package:foglm/features/camera/domain/upload_photo_failure.dart';
import 'package:foglm/features/camera/remaining_shots_provider.dart';
import 'package:foglm/features/camera/widgets/shutter_button.dart';

/// `/camera`ルートの`extra`として渡す引数。
class CameraArgs {
  const CameraArgs({required this.groupId});

  final String groupId;
}

/// カメラ撮影画面(S06)。
///
/// 撮影の残り枚数を表示し、上限に達した場合はシャッターボタンを
/// 操作不可にする(仕様書 4.1 S06 / 5.2.3)。撮影した写真は
/// `upload-photo` Edge Functionへ送信する(仕様書 3.4参照)。
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _controller;
  late final Future<void> _initializeControllerFuture;
  // takePicture()完了からuploadPhotoControllerProviderがローディング状態に
  // 遷移するまでの間はシャッターボタンがまだ操作可能なため、連打による
  // 二重撮影・二重送信を防ぐガードとして使う。
  bool _isCapturing = false;

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

  Future<void> _onShutterPressed() async {
    final controller = _controller;
    if (controller == null || _isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);

    try {
      final Uint8List bytes;
      try {
        final file = await controller.takePicture();
        bytes = await file.readAsBytes();
      } on Object {
        // takePicture()のCameraException、readAsBytes()のストレージI/O
        // エラー等をまとめて撮影失敗として扱う。
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('撮影に失敗しました')));
        }
        return;
      }
      if (!mounted) {
        return;
      }

      await ref
          .read(uploadPhotoControllerProvider.notifier)
          .submit(groupId: widget.groupId, bytes: bytes);

      if (!mounted) {
        return;
      }
      final state = ref.read(uploadPhotoControllerProvider);
      if (!state.hasError) {
        ref.read(remainingShotsProvider.notifier).decrement();
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = ref.watch(remainingShotsProvider);
    final isUploading =
        _isCapturing ||
        ref.watch(
          uploadPhotoControllerProvider.select((state) => state.isLoading),
        );

    ref.listen<AsyncValue<void>>(uploadPhotoControllerProvider, (
      previous,
      next,
    ) {
      // アップロード失敗を握り潰さず、ユーザーにも通知する。
      final error = next.error;
      if (error == null) {
        return;
      }
      if (error is DailyLimitReachedFailure) {
        ref.read(remainingShotsProvider.notifier).reachedLimit();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('本日の撮影上限に達しました')),
        );
      } else if (error is GroupArchivedFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('このグループは終了しているため撮影できません')),
        );
      } else if (error is NotActiveMemberFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('このグループのメンバーではないため撮影できません')),
        );
      } else if (error is EmailNotVerifiedFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メールアドレスの確認が完了していないため撮影できません')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('写真のアップロードに失敗しました。時間をおいて再度お試しください')),
        );
      }
    });

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
                  child: isUploading
                      ? const CircularProgressIndicator()
                      : ShutterButton(
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
