import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/settings_screen.dart';

const _key = 'last_backup_ms';

/// تسجيل وقت آخر نسخة احتياطية (يُستدعى بعد نجاح التصدير).
Future<void> markBackupDone() async {
  try {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_key, DateTime.now().millisecondsSinceEpoch);
  } catch (_) {}
}

Future<DateTime?> lastBackup() async {
  try {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getInt(_key);
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  } catch (_) {
    return null;
  }
}

/// بطاقة تذكير في الرئيسية: تظهر لو مرّ أكثر من 7 أيام على آخر نسخة (أو لم تؤخذ نسخة قط).
class BackupReminder extends StatefulWidget {
  const BackupReminder({super.key});
  @override
  State<BackupReminder> createState() => _BackupReminderState();
}

class _BackupReminderState extends State<BackupReminder> {
  late Future<DateTime?> _f = lastBackup();
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    return FutureBuilder<DateTime?>(
      future: _f,
      builder: (c, snap) {
        if (snap.connectionState != ConnectionState.done) return const SizedBox.shrink();
        final last = snap.data;
        final days = last == null ? null : DateTime.now().difference(last).inDays;
        if (days != null && days < 7) return const SizedBox.shrink();
        final cs = Theme.of(c).colorScheme;
        return Card(
          color: cs.errorContainer,
          child: ListTile(
            leading: Icon(Icons.backup_outlined, color: cs.onErrorContainer),
            title: Text(days == null ? 'لم تأخذ نسخة احتياطية بعد' : 'آخر نسخة احتياطية منذ $days يوم',
                style: TextStyle(fontWeight: FontWeight.bold, color: cs.onErrorContainer)),
            subtitle: Text('خذ نسخة الآن وانقلها خارج الهاتف حتى لا تضيع بياناتك.',
                style: TextStyle(color: cs.onErrorContainer)),
            trailing: IconButton(
                tooltip: 'إخفاء',
                icon: Icon(Icons.close, color: cs.onErrorContainer),
                onPressed: () => setState(() => _hidden = true)),
            onTap: () async {
              await Navigator.push(c, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              if (mounted) setState(() => _f = lastBackup());
            },
          ),
        );
      },
    );
  }
}
