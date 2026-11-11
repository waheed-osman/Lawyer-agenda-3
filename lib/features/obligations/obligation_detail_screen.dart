import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils.dart';
import '../../core/widgets.dart';
import '../../data/db.dart';
import '../../data/models.dart';
import 'obligation_form_screen.dart';

/// تفاصيل الالتزام: المتبقي، تسجيل سداد (كلي/جزئي)، سجل المدفوعات، تذكير واتساب.
class ObligationDetailScreen extends StatelessWidget {
  final int id;
  const ObligationDetailScreen({super.key, required this.id});

  Future<(Obligation?, List<ObligationPayment>)> _load() async =>
      (await Db.i.obligation(id), await Db.i.obligationPayments(id));

  String _wa(String raw) {
    var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('00')) d = d.substring(2);
    if (d.startsWith('0')) d = '20${d.substring(1)}';
    return d;
  }

  Future<void> _remind(BuildContext context, Obligation o, {bool sms = false}) async {
    final msg = 'السلام عليكم ${o.party.isEmpty ? '' : 'أستاذ/ ${o.party}'}،\n'
        'تذكير بخصوص "${o.title}"، المتبقي ${fmtMoney(o.remaining)}'
        '${o.due == null ? '' : ' والاستحقاق ${fmtShort(o.due!)}'}.\nشكرًا لك.';
    final text = Uri.encodeComponent(msg);
    final n = _wa(o.phone);
    final raw = o.phone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = sms ? Uri.parse('sms:$raw?body=$text') : Uri.parse(n.isEmpty ? 'https://wa.me/?text=$text' : 'https://wa.me/$n?text=$text');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) toast(context, 'تعذّر فتح واتساب');
    } catch (_) {
      if (context.mounted) toast(context, 'تعذّر فتح واتساب');
    }
  }

  Future<void> _pay(BuildContext context, Obligation o) async {
    final amount = TextEditingController(text: o.remaining.toStringAsFixed(o.remaining % 1 == 0 ? 0 : 2));
    final note = TextEditingController();
    var date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(o.incoming ? 'تسجيل قبض' : 'تسجيل سداد'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: dec('المبلغ'),
            ),
            const SizedBox(height: 8),
            TextField(controller: note, decoration: dec('ملاحظة (اختياري)')),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(fmtDate(date)),
              onTap: () async {
                final d = await pickDate(ctx, date);
                if (d != null) setS(() => date = d);
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    final v = parseAmount(amount.text);
    if (ok != true || v == null || v <= 0) return;
    await Db.i.addObligationPayment(o, v, date, note.text.trim());
    if (context.mounted) {
      toast(context, 'تم التسجيل');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Live<(Obligation?, List<ObligationPayment>)>(
      load: _load,
      builder: (c, data) {
        final o = data.$1;
        final pays = data.$2;
        if (o == null) {
          return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, text: 'غير موجود'));
        }
        final k = obligationKind(o.kind);
        final cs = Theme.of(c).colorScheme;
        final progress = o.amount <= 0 ? 0.0 : (o.paid / o.amount).clamp(0.0, 1.0).toDouble();
        return Scaffold(
          appBar: AppBar(
            title: Text(k.label),
            actions: [
              IconButton(
                tooltip: 'تعديل',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    Navigator.push(c, MaterialPageRoute(builder: (_) => ObligationFormScreen(edit: o))),
              ),
              IconButton(
                tooltip: 'حذف',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirm(c, 'حذف هذا الالتزام وكل مدفوعاته؟', ok: 'حذف')) {
                    await Db.i.deleteObligation(o.id!);
                    if (c.mounted) Navigator.pop(c);
                  }
                },
              ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(k.icon, color: k.color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(o.title, style: Theme.of(c).textTheme.titleMedium)),
                    if (o.done)
                      const Chip(label: Text('مسدَّد'), avatar: Icon(Icons.check_circle, color: Colors.green)),
                  ]),
                  if (o.party.isNotEmpty) Text('الطرف الآخر: ${o.party}'),
                  if (o.phone.isNotEmpty) Text('هاتف: ${o.phone}'),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(8)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('الإجمالي ${fmtMoney(o.amount)}'),
                    Text('المسدّد ${fmtMoney(o.paid)}'),
                  ]),
                  const SizedBox(height: 4),
                  Text('المتبقي: ${fmtMoney(o.remaining)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18, color: o.remaining > 0 ? cs.error : Colors.green)),
                  if (o.due != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.event, size: 18, color: o.overdue ? cs.error : null),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('الاستحقاق: ${fmtDate(o.due!)} (${relText(o.due!)})',
                            style: TextStyle(color: o.overdue ? cs.error : null)),
                      ),
                    ]),
                  ],
                  if (o.repeat != 'none') Text('يتكرر: ${repeatLabels[o.repeat]}'),
                  if (o.notes.isNotEmpty) ...[const SizedBox(height: 8), Text(o.notes)],
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (!o.done)
                FilledButton.icon(
                  onPressed: () => _pay(c, o),
                  icon: const Icon(Icons.add_card),
                  label: Text(o.incoming ? 'تسجيل قبض' : 'تسجيل سداد'),
                ),
              if (o.incoming && !o.done)
                OutlinedButton.icon(
                  onPressed: () => _remind(c, o),
                  icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                  label: const Text('تذكير واتساب'),
                ),
              if (o.incoming && !o.done)
                OutlinedButton.icon(
                  onPressed: () => _remind(c, o, sms: true),
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('تذكير SMS'),
                ),
            ]),
            const SizedBox(height: 16),
            Text('سجل المدفوعات', style: Theme.of(c).textTheme.titleSmall),
            const SizedBox(height: 4),
            if (pays.isEmpty)
              const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد مدفوعات مسجّلة'))
            else
              for (final p in pays)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_outlined),
                    title: Text(fmtMoney(p.amount)),
                    subtitle: Text('${fmtDate(p.date)}${p.note.isEmpty ? '' : '\n${p.note}'}'),
                    isThreeLine: p.note.isNotEmpty,
                    trailing: IconButton(
                      tooltip: 'حذف الدفعة',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (await confirm(c, 'حذف هذه الدفعة؟', ok: 'حذف')) {
                          await Db.i.deleteObligationPayment(p);
                        }
                      },
                    ),
                  ),
                ),
          ]),
        );
      },
    );
  }
}
