import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:foglm/features/auth/domain/public_user.dart';

/// ログイン中ユーザーの`public.users`行(認証ガード判定用)。
/// 未ログイン、または行が存在しない場合は`null`を返す。
final currentPublicUserProvider = FutureProvider<PublicUserRow?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    return null;
  }

  final row = await client
      .from('users')
      .select()
      .eq('id', userId)
      .maybeSingle();
  if (row == null) {
    return null;
  }
  return PublicUserRow.fromMap(row);
});
