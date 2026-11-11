import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../core/widgets.dart';
import '../../data/db.dart';
import '../../data/models.dart';
import '../../services/export.dart';

/// ورقة جلسات اليوم: كل الجلسات مرتبة بالمحكمة ثم الدائرة ثم الرول، للطباعة أو المشاركة واتساب.
class DaySheetScreen extends StatefulWidget {
  final DateTime? day;
  const DaySheetScreen({super.key, this.day});
  @override
  State<DaySheetScreen> createState() => _DaySheetScreenState();
}

class _DaySheetScreenState extends State<DaySheetScreen> {
  late DateTime _day = dayStart(widget.day ?? DateTime.now());

  Future<List<CaseSession>> _load() async {
    final l = await Db.i.sessions(from: _day, to: addDays(_day, 1));
    int rollNum(String r) => int.tryParse(r.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1 << 30;
    l.sort((a, b) {
      final c = a.court.compareTo(b.court);
      if (c != 0) return c;
      return rollNum(a.roll).compareTo(rollNum(b.roll));
    });
    return l;
  }

  ReportData _report(List<CaseSession> l) {
    final title = 'جلسات ${fmtDate(_day)}';
    final body = StringBuffer('<table><tr><th>م</th><th>المحكمة</th><th>الرول</th><th>القضية</th><th>الموكل</th><th>نوع الجلسة</th></tr>');
    final text = StringBuffer('$title\n');
    var i = 0;
    String? lastCourt;
    for (final s in l) {
      i++;
      body.write('<tr><td>$i</td><td>${Export.esc(s.court)}</td><td>${Export.esc(s.roll)}</td>'
          '<td>${Export.esc(caseLabel(s.caseNumber, s.caseYear))}</td><td>${Export.esc(s.clientName)}</td>'
          '<td>${Export.esc(sessionTypes[s.type] ?? '')}</td></tr>');
      if (s.court != lastCourt) {
        text.writeln('\n• ${s.court.isEmpty ? 'بدون محكمة' : s.court}');
        lastCourt = s.court;
      }
      text.writeln('  ${s.roll.isEmpty ? '-' : 'رول ${s.roll}'} | ${caseLabel(s.caseNumber, s.caseYear)}'
          '${s.clientName.isEmpty ? '' : ' | ${s.clientName}'} | ${sessionTypes[s.type] ?? ''}');
    }
    body.write('</table>');
    return Export.custom(title, body.toString(), text.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Live<List<CaseSession>>(
      load: _load,
      builder: (c, l) => Scaffold(
        appBar: AppBar(
          title: const Text('ورقة الجلسات'),
          actions: [
            IconButton(
              tooltip: 'طباعة / مشاركة',
              icon: const Icon(Icons.ios_share),
              onPressed: l.isEmpty ? null : () => Export.menu(c, () async => _report(l)),
            ),
          ],
        ),
        body: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                tooltip: 'اليوم السابق',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _day = addDays(_day, -1))),
            TextButton(
              onPressed: () async {
                final d = await pickDate(c, _day);
                if (d != null) setState(() => _day = dayStart(d));
              },
              child: Text('${relText(_day)} • ${fmtDate(_day)}'),
            ),
            IconButton(
                tooltip: 'اليوم التالي',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _day = addDays(_day, 1))),
          ]),
          Expanded(
            child: l.isEmpty
                ? const EmptyState(icon: Icons.event_available, text: 'لا توجد جلسات في هذا اليوم')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: l.length,
                    itemBuilder: (_, i) {
                      final s = l[i];
                      final newCourt = i == 0 || l[i - 1].court != s.court;
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (newCourt)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                            child: Text(s.court.isEmpty ? 'بدون محكمة' : s.court,
                                style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(c).colorScheme.primary)),
                          ),
                        Card(
                          child: ListTile(
                            leading: CircleAvatar(
                                backgroundColor: sessionColor(s.type).withOpacity(0.2),
                                child: Text(s.roll.isEmpty ? '-' : s.roll, style: const TextStyle(fontSize: 12))),
                            title: Text('${caseLabel(s.caseNumber, s.caseYear)}${s.clientName.isEmpty ? '' : ' • ${s.clientName}'}'),
                            subtitle: Text(sessionTypes[s.type] ?? ''),
                          ),
                        ),
                      ]);
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
