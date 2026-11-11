import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../core/widgets.dart';
import '../../data/db.dart';
import '../../data/models.dart';
import 'obligation_detail_screen.dart';
import 'obligation_form_screen.dart';

/// الالتزامات الشخصية والعائلية: ديون لي وعليّ، إيجارات، أقساط، فواتير.
class ObligationsScreen extends StatelessWidget {
  const ObligationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الالتزامات الشخصية'),
          bottom: const TabBar(tabs: [
            Tab(text: 'المفتوحة'),
            Tab(text: 'لي'),
            Tab(text: 'عليّ'),
            Tab(text: 'المسدّدة'),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ObligationFormScreen())),
          icon: const Icon(Icons.add),
          label: const Text('التزام جديد'),
        ),
        body: Live<List<Obligation>>(
          load: Db.i.obligations,
          builder: (c, all) {
            final open = all.where((o) => !o.done).toList();
            return Column(children: [
              _Summary(open: open),
              Expanded(
                child: TabBarView(children: [
                  _list(c, open),
                  _list(c, open.where((o) => o.incoming).toList()),
                  _list(c, open.where((o) => !o.incoming).toList()),
                  _list(c, all.where((o) => o.done).toList()),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _list(BuildContext c, List<Obligation> list) {
    if (list.isEmpty) {
      return const EmptyState(icon: Icons.account_balance_wallet_outlined, text: 'لا توجد التزامات هنا');
    }
    return ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 96), children: [
      for (final o in list) _Tile(o: o),
    ]);
  }
}

class _Summary extends StatelessWidget {
  final List<Obligation> open;
  const _Summary({required this.open});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    double toMe = 0, byMe = 0, monthDue = 0;
    var overdue = 0;
    final now = DateTime.now();
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    for (final o in open) {
      if (o.incoming) {
        toMe += o.remaining;
      } else {
        byMe += o.remaining;
        if (o.due != null && !dayStart(o.due!).isAfter(endOfMonth)) monthDue += o.remaining;
      }
      if (o.overdue) overdue++;
    }
    Widget cell(String label, double v, Color col) => Expanded(
          child: Column(children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(fmtMoney(v), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: col)),
            ),
          ]),
        );
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            cell('مستحق لي', toMe, const Color(0xFF2E7D32)),
            cell('عليّ', byMe, cs.error),
            cell('عليّ هذا الشهر', monthDue, const Color(0xFFEF6C00)),
          ]),
          if (overdue > 0) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: cs.error),
              const SizedBox(width: 4),
              Text('$overdue متأخر عن موعده', style: TextStyle(color: cs.error)),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Obligation o;
  const _Tile({required this.o});

  @override
  Widget build(BuildContext context) {
    final k = obligationKind(o.kind);
    final cs = Theme.of(context).colorScheme;
    final sub = <String>[
      if (o.party.isNotEmpty) o.party,
      if (o.due != null) '${fmtShort(o.due!)} • ${relText(o.due!)}',
      if (o.repeat != 'none') repeatLabels[o.repeat]!,
      if (o.paid > 0 && !o.done) 'مسدّد ${fmtMoney(o.paid)}',
    ];
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: k.color.withOpacity(0.15),
          child: Icon(k.icon, color: k.color),
        ),
        title: Text(o.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sub.join(' • '), style: TextStyle(color: o.overdue ? cs.error : null)),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmtMoney(o.done ? o.amount : o.remaining),
              style: TextStyle(fontWeight: FontWeight.bold, color: o.done ? Colors.green : k.color)),
          Text(k.label, style: Theme.of(context).textTheme.bodySmall),
        ]),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => ObligationDetailScreen(id: o.id!))),
      ),
    );
  }
}
