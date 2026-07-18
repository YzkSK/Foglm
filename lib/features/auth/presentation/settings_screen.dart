import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/application/my_profile_provider.dart';
import 'package:foglm/features/auth/application/sign_out_controller.dart';
import 'package:go_router/go_router.dart';

/// 設定・マイページ画面(S12)。
///
/// アカウント情報の表示、プロフィール編集・ログアウト・アカウント削除への
/// 導線を提供する(仕様書 4.1 S12参照)。通知設定はFCM送信基盤が未整備のため
/// 本画面のスコープには含めない。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    final signOutState = ref.watch(signOutControllerProvider);
    final isSigningOut = signOutState.isLoading;

    ref.listen<AsyncValue<void>>(signOutControllerProvider, (
      previous,
      next,
    ) {
      // signOut失敗を握り潰さず、ユーザーにも通知する。
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ログアウトに失敗しました。時間をおいて再度お試しください')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('設定・マイページ')),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('アカウント情報を取得できませんでした'));
            }
            return ListView(
              children: [
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(profile.displayName),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('プロフィール編集'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile'),
                ),
                ListTile(
                  title: const Text('ログアウト'),
                  enabled: !isSigningOut,
                  trailing: isSigningOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: isSigningOut
                      ? null
                      : () => ref
                            .read(signOutControllerProvider.notifier)
                            .signOut(),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(
                    'アカウント削除',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onTap: () => context.push('/account/delete'),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            // myProfileProviderの取得失敗を握り潰さず記録する。
            developer.log(
              'myProfileProvider failed to load',
              name: 'SettingsScreen',
              error: error,
              stackTrace: stackTrace,
            );
            return const Center(child: Text('アカウント情報の取得に失敗しました'));
          },
        ),
      ),
    );
  }
}
