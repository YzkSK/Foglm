import 'dart:async';
import 'dart:developer' as developer;
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
  // サーバーが上限超過(daily_limit_reached)を返した場合、Realtime経由の
  // 反映(他メンバーの撮影がないと発火しない)を待たずに即座にシャッターを
  // 操作不可にするためのローカルな上書きフラグ(仕様書 5.2.3参照)。
  // remainingShotsProviderが新しい値を1回でも発行したら、そちらの方が
  // 新しいサーバー真実であるため解除する(そうしないと、日付が変わって
  // 上限がリセットされても画面を開いたままだと永久に0のままになる)。
  bool _limitReachedOverride = false;
  // 撮影成功直後、自分のphotos INSERTがRealtime経由で反映されるまでの
  // ラグの間、残数バッジ・シャッターの操作可否を楽観的に更新するための
  // ローカルな減算量。remainingShotsProviderが新しい値を発行したら
  // (自分の撮影も含めて反映済みのはずなので)0に戻す。
  int _optimisticDecrement = 0;

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
    final controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
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
      final uploadState = ref.read(uploadPhotoControllerProvider);
      if (!uploadState.hasError) {
        // 自分のphotos INSERTがRealtimeで反映されるまでのラグの間、
        // 残数表示・シャッターの操作可否を楽観的に更新する。
        setState(() => _optimisticDecrement++);
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final remainingAsync = ref.watch(remainingShotsProvider(widget.groupId));

    ref.listen<AsyncValue<int>>(remainingShotsProvider(widget.groupId), (
      previous,
      next,
    ) {
      // remainingShotsProviderが新しい値を発行したら、それがローカルの
      // 上書き・楽観的減算より新しいサーバー真実になる。上書きしたままだと
      // 日付が変わって上限がリセットされても画面を開いたままだと永久に
      // 古い状態に固定されてしまうため、ここで解除する。
      if (next.hasValue &&
          (_limitReachedOverride || _optimisticDecrement != 0)) {
        setState(() {
          _limitReachedOverride = false;
          _optimisticDecrement = 0;
        });
      }
      final error = next.error;
      if (error != null) {
        // 残数取得の失敗を握り潰さず記録する。最終的な上限担保はDBトリガー
        // 側にあるため、この画面ではfail-safe(0扱いでシャッターを止める)
        // にする。
        developer.log(
          'remainingShotsProvider failed to load',
          name: 'CameraScreen',
          error: error,
          stackTrace: next.stackTrace,
        );
      }
    });

    // 取得中・取得失敗の間はまだ実際の残数が分からないため、上限超過を
    // 防ぐ安全側の挙動としてシャッターを操作不可にする(仕様書 5.2.3参照)。
    final rawRemaining = remainingAsync.value ?? 0;
    final remaining = _limitReachedOverride
        ? 0
        : (rawRemaining - _optimisticDecrement).clamp(0, rawRemaining);
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
        setState(() => _limitReachedOverride = true);
        // 自分の撮影は上限超過でDBに登録されなかった(photosがINSERTされて
        // いない)ため、Realtime購読だけでは更新されない。明示的に
        // 再取得させることで、上のref.listenが実際のサーバー値が届き
        // 次第_limitReachedOverrideを解除できるようにする。
        ref.invalidate(remainingShotsProvider(widget.groupId));
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
