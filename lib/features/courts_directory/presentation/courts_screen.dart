import 'package:flutter/material.dart';

import '../../../core/widgets.dart';
import '../data/court.dart';
import '../data/courts_repo.dart';
import '../../../core/utils.dart';
import 'barcode_scan_screen.dart';
import 'court_detail_screen.dart';
import 'court_form_screen.dart';

/// دليل المحاكم: بحث + تصفية بالمحافظة. في وضع [pick] يعيد الجهة المختارة (لنموذج القضية).
class CourtsScreen extends StatefulWidget {
  final bool pick;
  const CourtsScreen({super.key, this.pick = false});
  @override
  State<CourtsScreen> createState() => _CourtsScreenState();
}

class _CourtsScreenState extends State<CourtsScreen> {
  String _q = '';
  String? _gov;

  /// مسح باركود محكمة: إن كانت محفوظة نفتحها، وإلا نفتح نموذج جهة جديدة برابط القرارات.
  Future<void> _scan() async {
    final v = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const BarcodeScanScreen()));
    if (v == null || !mounted) return;
    final all = await CourtsRepo.list();
    final hit = all.where((c) => c.decisionsUrl.trim() == v.trim()).firstOrNull;
    if (!mounted) return;
    if (hit != null) {
      toast(context, 'هذه المحكمة مسجلة: ${hit.name}');
      Navigator.push(context, MaterialPageRoute(builder: (_) => CourtDetailScreen(id: hit.id!)));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CourtFormScreen(scanned: v)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pick ? 'اختر المحكمة من الدليل' : 'دليل المحاكم'), actions: [
        IconButton(tooltip: 'مسح باركود محكمة', icon: const Icon(Icons.qr_code_scanner), onPressed: _scan),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CourtFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('جهة'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
                hintText: 'ابحث بالاسم أو العنوان أو الاختصاص...', prefixIcon: Icon(Icons.search), isDense: true),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        SizedBox(
          height: 48,
          child: Live<List<String>>(
            load: CourtsRepo.governoratesInUse,
            builder: (c, govs) => govs.isEmpty
                ? const SizedBox.shrink()
                : ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: ChoiceChip(
                            label: const Text('الكل'), selected: _gov == null, onSelected: (_) => setState(() => _gov = null)),
                      ),
                      for (final g in govs)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: ChoiceChip(
                              label: Text(g), selected: _gov == g, onSelected: (_) => setState(() => _gov = g)),
                        ),
                    ],
                  ),
          ),
        ),
        Expanded(
          child: Live<List<Court>>(
            load: () => CourtsRepo.list(q: _q, governorate: _gov),
            builder: (c, list) {
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.account_balance_outlined,
                  text: (_q.trim().isEmpty && _gov == null)
                      ? 'الدليل فارغ.\nاضغط "جهة" لإضافة محكمة أو نيابة تتعامل معها،\nمع عنوانها واختصاصها ورابط موقعها.'
                      : 'لا توجد نتائج مطابقة',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final x = list[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.account_balance),
                      title: Text(x.name),
                      subtitle: Text([x.subtitle, x.address].where((e) => e.trim().isNotEmpty).join('\n'),
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                      isThreeLine: x.subtitle.isNotEmpty && x.address.trim().isNotEmpty,
                      trailing: Icon(widget.pick ? Icons.check_circle_outline : Icons.chevron_left),
                      onTap: () => widget.pick
                          ? Navigator.pop(context, x)
                          : Navigator.push(
                              context, MaterialPageRoute(builder: (_) => CourtDetailScreen(id: x.id!))),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
