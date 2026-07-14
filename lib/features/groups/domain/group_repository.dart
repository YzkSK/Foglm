import 'package:foglm/features/groups/domain/my_group.dart';

abstract class GroupRepository {
  Future<void> createGroup({required String name});

  Future<void> createEventGroup({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<List<MyGroupRow>> getMyGroups();

  Future<void> joinGroupByCode({required String code});

  Future<void> leaveGroup({required String groupId});

  Future<String> createInviteCode({required String groupId});

  Future<String?> getInviteCode({required String groupId});
}
