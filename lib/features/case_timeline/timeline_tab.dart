import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../core/widgets.dart';
import '../../data/db.dart';
import '../../data/models.dart';
import '../../screens/session_form_screen.dart';

/// خط زمني لتأجيلات القضية: كل جلسة بتاريخها ورولها وقرارها والمدة منذ الجلسة السابقة.
class CaseTimelineTab extends StatelessWidget {
  final int caseId;
  const CaseTimelineTab({super.key, required this.caseId});

  @override
  Widget build(BuildContext context) {
    return Live<List<CaseSession>>(
      load: () => Db.i.sessions(caseId: caseId),
      builder: (c, list) {
        if (list.isEmpty) return const EmptyState(icon: Icons.timeline, text: 'لا توجد جلسات بعد');
        final gaps = <int>[];
        for (var i = 1; i < list.length; i++) {
          gaps.add(dayStart(list[i].date).difference(dayStart(list[i - 1].date)).inDays);
        }
        final avg = gaps.isEmpty ? 0 : (gaps.reduce((a, b) => a + b) / gaps.length).round();
        final cs = Theme.of(c).colorScheme;
        return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: [
          Card(
            color: cs.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.timeline),
              title: Text('${list.length} جلسة • ${list.length - 1 < 0 ? 0 : list.length - 1} تأجيل'),
              subtitle: Text(gaps.isEmpty ? 'جلسة واحدة حتى الآن' : 'متوسط المدة بين الجلسات: $avg يوم'),
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < list.length; i++)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  width: 28,
                  child: Column(children: [
                    Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(top: 18),
                        decoration: BoxDecoration(color: sessionColor(list[i].type), shape: BoxShape.circle)),
                    if (i < list.length - 1) Expanded(child: Container(width: 2, color: cs.outlineVariant)),
                  ]),
                ),
                Expanded(
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(
                          c,
                          MaterialPageRoute(
                              builder: (_) => SessionFormScreen(caseId: caseId, sessionId: list[i].id))),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            StatusChip(sessionTypes[list[i].type] ?? '', sessionColor(list[i].type)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(fmtDate(list[i].date), style: const TextStyle(fontWeight: FontWeight.bold))),
                          ]),
                          if (i > 0)
                            Text('بعد ${gaps[i - 1]} يوم من الجلسة السابقة',
                                style: TextStyle(fontSize: 12, color: cs.outline)),
                          if (list[i].roll.isNotEmpty) Text('الرول: ${list[i].roll}'),
                          if (list[i].decision.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('القرار: ${list[i].decision}'),
                          ],
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
        ]);
      },
    );
  }
}
