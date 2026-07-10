interface GroupIdRow {
  group_id: string;
}

/** 更新済みの写真行をgroup_idごとに集計する(通知集約に使う)。 */
export function aggregateDevelopedCountsByGroup(rows: GroupIdRow[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const row of rows) {
    counts.set(row.group_id, (counts.get(row.group_id) ?? 0) + 1);
  }
  return counts;
}
