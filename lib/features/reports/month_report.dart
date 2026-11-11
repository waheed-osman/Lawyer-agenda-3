import '../../core/utils.dart';
import '../../data/db.dart';
import '../../services/export.dart';

/// تقرير شهري: الجلسات، القضايا، التحصيل والمتأخرات.
class MonthReport {
  static Future<ReportData> build(DateTime anyDay) async {
    final from = DateTime(anyDay.year, anyDay.month, 1);
    final to = DateTime(anyDay.year, anyDay.month + 1, 1);
    final title = 'تقرير شهر ${anyDay.month}/${anyDay.year}';
    final d = await Db.i.db;
    final f = from.millisecondsSinceEpoch, t = to.millisecondsSinceEpoch;

    final sessions = await Db.i.sessions(from: from, to: to);
    final byType = <String, int>{};
    for (final s in sessions) {
      byType[s.type] = (byType[s.type] ?? 0) + 1;
    }
    final withDecision = sessions.where((s) => s.decision.trim().isNotEmpty).length;

    final newCases = (await d.rawQuery('SELECT COUNT(*) AS n FROM cases WHERE created_at>=? AND created_at<?', [f, t]))
        .first['n'] as int;
    final counts = await Db.i.counts();
    final archived = (await d.rawQuery('SELECT COUNT(*) AS n FROM cases WHERE IFNULL(archived,0)=1')).first['n'] as int;

    Future<double> monthSum(String kind) async {
      final r = await d.rawQuery('SELECT SUM(amount) AS t FROM payments WHERE kind=? AND date>=? AND date<?', [kind, f, t]);
      return (r.first['t'] as num?)?.toDouble() ?? 0;
    }

    final paid = await monthSum('payment');
    final newFees = await monthSum('fee');
    final expenses = await monthSum('expense');
    final deposits = await monthSum('deposit');
    final balances = await Db.i.clientBalances();
    final overdue = balances.where((b) => b.remaining > 0).toList()..sort((a, b) => b.remaining.compareTo(a.remaining));
    final overdueTotal = overdue.fold<double>(0, (s, b) => s + b.remaining);

    final rows1 = <List<String>>[
      ['عدد الجلسات', '${sessions.length}'],
      for (final e in byType.entries) ['  • ${sessionTypes[e.key] ?? e.key}', '${e.value}'],
      ['جلسات سُجّل لها قرار', '$withDecision'],
      ['قضايا جديدة', '$newCases'],
      ['قضايا جارية', '${counts['active'] ?? 0}'],
      ['قضايا مؤجلة', '${counts['postponed'] ?? 0}'],
      ['قضايا مكتسبة', '${counts['won'] ?? 0}'],
      ['قضايا خاسرة', '${counts['lost'] ?? 0}'],
      ['قضايا مؤرشفة', '$archived'],
    ];
    final rows2 = <List<String>>[
      ['أتعاب جديدة متفق عليها', fmtMoney(newFees)],
      ['دفعات أتعاب محصّلة', fmtMoney(paid)],
      ['أمانات مستلمة', fmtMoney(deposits)],
      ['مصروفات قضائية', fmtMoney(expenses)],
      ['إجمالي المتأخر على الموكلين (الآن)', fmtMoney(overdueTotal)],
    ];

    final h = StringBuffer('<h2>النشاط</h2><table>');
    for (final r in rows1) {
      h.write('<tr><td class="k">${Export.esc(r[0])}</td><td>${Export.esc(r[1])}</td></tr>');
    }
    h.write('</table><h2>الماليات</h2><table>');
    for (final r in rows2) {
      h.write('<tr><td class="k">${Export.esc(r[0])}</td><td>${Export.esc(r[1])}</td></tr>');
    }
    h.write('</table>');
    if (overdue.isNotEmpty) {
      h.write('<h2>أعلى المتأخرات</h2><table><tr><th>الموكل</th><th>المتبقي</th></tr>');
      for (final b in overdue.take(10)) {
        h.write('<tr><td>${Export.esc(b.client.name)}</td><td>${Export.esc(fmtMoney(b.remaining))}</td></tr>');
      }
      h.write('</table>');
    }

    final txt = StringBuffer('$title\n\n— النشاط —\n');
    for (final r in rows1) {
      txt.writeln('${r[0]}: ${r[1]}');
    }
    txt.writeln('\n— الماليات —');
    for (final r in rows2) {
      txt.writeln('${r[0]}: ${r[1]}');
    }
    return Export.custom(title, h.toString(), txt.toString());
  }
}
