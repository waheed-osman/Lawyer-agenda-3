import 'package:flutter/material.dart';

import 'utils.dart';
import 'widgets.dart';

/// بطاقة اختيار تنبيه مخصص (تاريخ + وقت). عند تحديده يحل محل التنبيهين الافتراضيين.
class ReminderTile extends StatelessWidget {
  final DateTime? value;
  final DateTime anchor; // تاريخ الجلسة/الموعد (للاقتراح الأولي)
  final ValueChanged<DateTime?> onChanged;
  const ReminderTile({super.key, required this.value, required this.anchor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = value;
    return ListTile(
      shape: RoundedRectangleBorder(
          side: BorderSide(color: cs.outlineVariant), borderRadius: BorderRadius.circular(12)),
      leading: const Icon(Icons.notifications_active_outlined),
      title: const Text('تنبيه مخصص (التاريخ والوقت)'),
      subtitle: Text(v == null
          ? 'الافتراضي: مساء اليوم السابق + صباح اليوم (يُعدَّل من الإعدادات)'
          : '${fmtDate(v)} • ${fmtTime(v.hour * 60 + v.minute)}'),
      trailing: v == null
          ? null
          : IconButton(tooltip: 'العودة للافتراضي', icon: const Icon(Icons.close), onPressed: () => onChanged(null)),
      onTap: () async {
        final d = await pickDate(context, v ?? addDays(anchor, -1));
        if (d == null || !context.mounted) return;
        final t = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: v?.hour ?? 18, minute: v?.minute ?? 0),
        );
        if (t == null) return;
        onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute));
      },
    );
  }
}
