import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../core/widgets.dart';
import '../../data/db.dart';
import '../../data/models.dart';
import '../../screens/case_detail_screen.dart';
import '../../screens/client_detail_screen.dart';
import '../../screens/document_form_screen.dart';
import '../../screens/library_file_screen.dart';
import '../../screens/library_screen.dart';
import '../courts_directory/data/court.dart';
import '../courts_directory/data/courts_repo.dart';
import '../courts_directory/presentation/court_detail_screen.dart';
import '../links/links_screen.dart';

class _Hit {
  final String section, title, subtitle;
  final IconData icon;
  final VoidCallback Function(BuildContext) open;
  _Hit(this.section, this.title, this.subtitle, this.icon, this.open);
}

/// بحث شامل واحد: القضايا والموكلون والمذكرات والمكتبة (نماذج وملفات) والمحاكم والروابط.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});
  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _ctrl = TextEditingController();
  List<_Hit> _hits = [];
  bool _busy = false;
  bool _searched = false;
  int _seq = 0;

  void _go(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

  Future<void> _search(String q) async {
    final my = ++_seq;
    q = q.trim();
    if (q.length < 2) {
      setState(() {
        _hits = [];
        _searched = false;
      });
      return;
    }
    setState(() => _busy = true);
    final out = <_Hit>[];
    final d = await Db.i.db;
    final like = '%$q%';

    for (final x in await Db.i.cases(q: q)) {
      out.add(_Hit('القضايا', caseLabel(x.number, x.year),
          [x.clientName, x.court, if (x.archived) 'مؤرشفة'].where((e) => e.isNotEmpty).join(' • '), Icons.gavel,
          (c) => () => _go(c, CaseDetailScreen(caseId: x.id!))));
    }
    for (final x in await Db.i.clients(q: q)) {
      out.add(_Hit('الموكلون', x.name, x.phone, Icons.person,
          (c) => () => _go(c, ClientDetailScreen(clientId: x.id!))));
    }
    final docs = await d.rawQuery(
        "SELECT d.id, d.case_id, d.title, d.category, c.number, c.year FROM documents d "
        "JOIN cases c ON c.id=d.case_id WHERE d.title LIKE ? OR d.body LIKE ? ORDER BY d.updated_at DESC LIMIT 30",
        [like, like]);
    for (final r in docs) {
      out.add(_Hit('المذكرات', (r['title'] ?? '').toString(),
          '${r['category'] ?? ''} • ${caseLabel((r['number'] ?? '').toString(), (r['year'] ?? '').toString())}',
          Icons.description_outlined,
          (c) => () => _go(c, DocumentFormScreen(caseId: (r['case_id'] as num).toInt(), docId: (r['id'] as num).toInt()))));
    }
    for (final x in await Db.i.templates(q: q)) {
      out.add(_Hit('النماذج القانونية', x.title, x.category, Icons.article_outlined,
          (c) => () => _go(c, TemplateViewScreen(id: x.id!))));
    }
    for (final x in await Db.i.libraryFiles(q: q)) {
      out.add(_Hit('ملفات المكتبة', x.title, [x.ref, x.category].where((e) => e.isNotEmpty).join(' • '),
          x.ext == 'pdf' ? Icons.picture_as_pdf : Icons.description,
          (c) => () => _go(c, LibraryFileScreen(id: x.id!))));
    }
    for (final Court x in await CourtsRepo.list(q: q)) {
      out.add(_Hit('المحاكم', x.name, [x.kind, x.governorate].where((e) => e.isNotEmpty).join(' • '),
          Icons.account_balance, (c) => () => _go(c, CourtDetailScreen(id: x.id!))));
    }
    for (final x in await LinksRepo.list(q: q)) {
      out.add(_Hit('الروابط', x.title, x.url, Icons.link, (c) => () => _go(c, const LinksScreen())));
    }
    if (!mounted || my != _seq) return;
    setState(() {
      _hits = out;
      _busy = false;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sections = <String>[];
    for (final h in _hits) {
      if (!sections.contains(h.section)) sections.add(h.section);
    }
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'ابحث في كل التطبيق...', border: InputBorder.none),
          onChanged: _search,
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _ctrl.clear();
                  _search('');
                }),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : !_searched
              ? const EmptyState(icon: Icons.search, text: 'اكتب حرفين على الأقل للبحث')
              : _hits.isEmpty
                  ? const EmptyState(icon: Icons.search_off, text: 'لا توجد نتائج')
                  : ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: [
                      for (final s in sections) ...[
                        SectionTitle('$s (${_hits.where((h) => h.section == s).length})'),
                        for (final h in _hits.where((h) => h.section == s))
                          Card(
                            child: ListTile(
                              leading: Icon(h.icon),
                              title: Text(h.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: h.subtitle.isEmpty ? null : Text(h.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                              onTap: h.open(context),
                            ),
                          ),
                      ],
                    ]),
    );
  }
}
