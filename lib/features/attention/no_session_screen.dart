import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../../data/db.dart';
import '../../data/models.dart';
import '../../screens/case_detail_screen.dart';
import '../../screens/session_form_screen.dart';

/// قضايا جارية/مؤجلة ليس لها جلسة قادمة: تحتاج تحديد موعد أو تغيير الحالة.
class NoSessionScreen extends StatelessWidget {
  const NoSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قضايا بدون جلسة قادمة')),
      body: Live<List<LegalCase>>(
        load: Db.i.casesWithoutNextSession,
        builder: (c, list) => list.isEmpty
            ? const EmptyState(icon: Icons.task_alt, text: 'كل القضايا الجارية لها جلسة قادمة')
            : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: [
                for (final x in list)
                  Column(children: [
                    CaseCard(
                        c: x,
                        onTap: () => Navigator.push(
                            c, MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: x.id!)))),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => Navigator.push(
                            c, MaterialPageRoute(builder: (_) => SessionFormScreen(caseId: x.id!))),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة جلسة'),
                      ),
                    ),
                  ]),
              ]),
      ),
    );
  }
}
