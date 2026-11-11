import 'package:flutter/material.dart';

import '../../core/reminder_tile.dart';
import '../../core/utils.dart';
import '../../core/widgets.dart';
import '../../data/db.dart';
import '../../data/models.dart';

/// إضافة/تعديل التزام شخصي: دَين، إيجار، قسط، فاتورة...
class ObligationFormScreen extends StatefulWidget {
  final Obligation? edit;
  const ObligationFormScreen({super.key, this.edit});
  @override
  State<ObligationFormScreen> createState() => _ObligationFormScreenState();
}

class _ObligationFormScreenState extends State<ObligationFormScreen> {
  final _form = GlobalKey<FormState>();
  late String _kind;
  late String _repeat;
  DateTime? _due;
  DateTime? _remindAt;
  final _title = TextEditingController();
  final _party = TextEditingController();
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  final _paid = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final o = widget.edit;
    _kind = o?.kind ?? 'owed_by_me';
    _repeat = o?.repeat ?? 'none';
    _due = o?.due;
    _remindAt = o?.remindAt;
    if (o != null) {
      _title.text = o.title;
      _party.text = o.party;
      _phone.text = o.phone;
      _amount.text = o.amount == 0 ? '' : o.amount.toStringAsFixed(o.amount % 1 == 0 ? 0 : 2);
      _paid.text = o.paid == 0 ? '' : o.paid.toStringAsFixed(o.paid % 1 == 0 ? 0 : 2);
      _notes.text = o.notes;
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _party, _phone, _amount, _paid, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final amount = parseAmount(_amount.text) ?? 0;
    final paid = parseAmount(_paid.text) ?? 0;
    if (amount <= 0) {
      toast(context, 'اكتب المبلغ');
      return;
    }
    final o = widget.edit ?? Obligation();
    o
      ..kind = _kind
      ..title = _title.text.trim()
      ..party = _party.text.trim()
      ..phone = _phone.text.trim()
      ..notes = _notes.text.trim()
      ..amount = amount
      ..paid = paid
      ..due = _due
      ..repeat = _due == null ? 'none' : _repeat
      ..remindAt = _remindAt;
    await Db.i.saveObligation(o);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final k = obligationKind(_kind);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.edit == null ? 'التزام جديد' : 'تعديل الالتزام'),
        actions: [TextButton(onPressed: _save, child: const Text('حفظ'))],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('النوع', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final e in obligationKinds.entries)
              ChoiceChip(
                avatar: Icon(e.value.icon, size: 18, color: e.value.color),
                label: Text(e.value.label),
                selected: _kind == e.key,
                onSelected: (_) => setState(() => _kind = e.key),
              ),
          ]),
          const SizedBox(height: 16),
          tf(_title, k.incoming ? 'البيان (مثال: سلفة، إيجار شقة...)' : 'البيان (مثال: قسط السيارة، فاتورة الكهرباء)',
              icon: Icons.title, required: true),
          tf(_party, k.partyLabel, icon: Icons.person_outline),
          tf(_phone, 'رقم الهاتف (اختياري، لتذكير واتساب)', icon: Icons.phone_outlined, type: TextInputType.phone),
          tf(_amount, 'المبلغ', icon: Icons.payments_outlined, type: const TextInputType.numberWithOptions(decimal: true)),
          tf(_paid, 'المسدّد حتى الآن (اختياري)', icon: Icons.check_circle_outline,
              type: const TextInputType.numberWithOptions(decimal: true)),
          ListTile(
            shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.event),
            title: const Text('تاريخ الاستحقاق'),
            subtitle: Text(_due == null ? 'بدون تاريخ' : fmtDate(_due!)),
            trailing: _due == null
                ? null
                : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _due = null)),
            onTap: () async {
              final d = await pickDate(context, _due ?? DateTime.now());
              if (d != null) setState(() => _due = d);
            },
          ),
          const SizedBox(height: 12),
          if (_due != null) ...[
            DropdownButtonFormField<String>(
              value: _repeat,
              decoration: dec('التكرار', icon: Icons.repeat),
              items: [
                for (final e in repeatLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _repeat = v ?? 'none'),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                _repeat == 'none'
                    ? ''
                    : 'عند تسجيل السداد الكامل يُنشأ الاستحقاق التالي تلقائيًا.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            ReminderTile(
              value: _remindAt,
              anchor: _due!,
              onChanged: (v) => setState(() => _remindAt = v),
            ),
            const SizedBox(height: 12),
          ],
          tf(_notes, 'ملاحظات', icon: Icons.notes, maxLines: 3),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('حفظ')),
        ]),
      ),
    );
  }
}
