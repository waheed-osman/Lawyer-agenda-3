import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils.dart';
import '../../core/widgets.dart';
import '../../data/db.dart';
import '../../screens/client_detail_screen.dart';

/// الأتعاب المتأخرة: الموكلون الذين عليهم متبقٍ، مع تذكير مهذب بواتساب.
class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});
  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  double _min = 0;

  String _wa(String raw) {
    var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('00')) d = d.substring(2);
    if (d.startsWith('0')) d = '20${d.substring(1)}';
    return d;
  }

  Future<void> _remind(ClientBalance b, {bool sms = false}) async {
    final msg = 'السيد/ ${b.client.name} المحترم،\nتحية طيبة وبعد،\n'
        'نود التذكير بأن المتبقي من الأتعاب المتفق عليها ${fmtMoney(b.remaining)}. '
        'نرجو التكرم بالسداد في أقرب وقت، ولسيادتكم جزيل الشكر والتقدير.';
    final text = Uri.encodeComponent(msg);
    final n = _wa(b.client.phone);
    final raw = b.client.phone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = sms ? Uri.parse('sms:$raw?body=$text') : Uri.parse(n.isEmpty ? 'https://wa.me/?text=$text' : 'https://wa.me/$n?text=$text');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) toast(context, 'تعذّر فتح واتساب');
    } catch (_) {
      if (mounted) toast(context, 'تعذّر فتح واتساب');
    }
  }

  Future<void> _setMin() async {
    final c = TextEditingController(text: _min == 0 ? '' : _min.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إظهار المتبقي من مبلغ'),
        content: TextField(controller: c, keyboardType: TextInputType.number, decoration: dec('الحد الأدنى للمتبقي')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تطبيق')),
        ],
      ),
    );
    if (ok == true) setState(() => _min = (double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأتعاب المتأخرة'), actions: [
        IconButton(tooltip: 'تصفية بالمبلغ', icon: const Icon(Icons.filter_alt_outlined), onPressed: _setMin),
      ]),
      body: Live<List<ClientBalance>>(
        load: Db.i.clientBalances,
        builder: (c, all) {
          final list = all.where((b) => b.remaining > 0 && b.remaining >= _min).toList()
            ..sort((a, b) => b.remaining.compareTo(a.remaining));
          final total = list.fold<double>(0, (s, b) => s + b.remaining);
          if (list.isEmpty) return const EmptyState(icon: Icons.paid_outlined, text: 'لا توجد أتعاب متأخرة');
          return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: [
            Card(
              color: Theme.of(c).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text('إجمالي المتأخر: ${fmtMoney(total)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${list.length} موكل'),
              ),
            ),
            for (final b in list)
              Card(
                child: ListTile(
                  title: Text(b.client.name),
                  subtitle: Text('أتعاب ${fmtMoney(b.fee)} • مدفوع ${fmtMoney(b.paid)}\nالمتبقي: ${fmtMoney(b.remaining)}'),
                  isThreeLine: true,
                  onTap: () => Navigator.push(
                      c, MaterialPageRoute(builder: (_) => ClientDetailScreen(clientId: b.client.id!))),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'تذكير SMS',
                      icon: const Icon(Icons.sms_outlined),
                      onPressed: () => _remind(b, sms: true),
                    ),
                    IconButton(
                      tooltip: 'تذكير واتساب',
                      icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                      onPressed: () => _remind(b),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
