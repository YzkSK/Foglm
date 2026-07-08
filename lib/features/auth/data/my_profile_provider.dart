import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:foglm/features/auth/domain/my_profile.dart';

/// ログイン中ユーザーのプロフィール(ニックネーム・アイコンURL)。
/// プロフィール編集画面(S12内、#7)の初期値表示に使う。
final myProfileProvider = FutureProvider<MyProfileRow?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    return null;
  }

  final row = await client
      .from('users')
      .select('display_name, avatar_url')
      .eq('id', userId)
      .maybeSingle();
  if (row == null) {
    return null;
  }
  return MyProfileRow.fromMap(row);
});
