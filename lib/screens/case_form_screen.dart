import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../core/widgets.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../features/courts_directory/data/court.dart';
import '../features/courts_directory/presentation/courts_screen.dart';
import 'client_form_screen.dart';

class CaseFormScreen extends StatefulWidget {
  final int? caseId;
  final int? clientId;
  /// نسخ بيانات قضية (الموكل والمحكمة والخصم...) لقضية جديدة.
  final int? copyFrom;
  const CaseFormScreen({super.key, this.caseId, this.clientId, this.copyFrom});
  @override
  State<CaseFormScreen> createState() => _CaseFormScreenState();
}

class _CaseFormScreenState extends State<CaseFormScreen> {
  final _form = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _year = TextEditingController(text: DateTime.now().year.toString());
  final _circuit = TextEditingController();
  final _court = TextEditingController();
  final _opponent = TextEditingController();
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _poaNo = TextEditingController();
  final _poaOffice = TextEditingController();
  final _poaPrincipal = TextEditingController();
  final _poaNotes = TextEditingController();
  String _poaKind = '';
  DateTime? _poaDate, _poaExpiry;
  String _role = clientRoles.first;
  String _type = caseTypes.first;
  String _status = 'active';
  int? _clientId;
  LegalCase? _orig;
  List<Client> _clients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _clients = await Db.i.clients();
    _clientId = widget.clientId;
    final srcId = widget.caseId ?? widget.copyFrom;
    if (srcId != null) {
      final c = await Db.i.legalCase(srcId);
      if (c != null) {
        if (widget.caseId != null) _orig = c;
        _number.text = c.number;
        _year.text = c.year;
        _circuit.text = c.circuit;
        _court.text = c.court;
        _opponent.text = c.opponent;
        _title.text = c.title;
        _notes.text = c.notes;
        _role = clientRoles.contains(c.clientRole) ? c.clientRole : clientRoles.first;
        _type = caseTypes.contains(c.type) ? c.type : caseTypes.last;
        _status = widget.caseId != null ? c.status : 'active';
        _clientId = c.clientId;
        _poaNo.text = c.poaNo;
        _poaOffice.text = c.poaOffice;
        _poaPrincipal.text = c.poaPrincipal;
        _poaNotes.text = c.poaNotes;
        _poaKind = poaKinds.contains(c.poaKind) ? c.poaKind : '';
        _poaDate = c.poaDate;
        _poaExpiry = c.poaExpiry;
        if (widget.caseId == null) {
          _number.clear(); // رقم القضية الجديدة يُكتب يدويًا
          _notes.clear();
        }
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _newClient() async {
    final id = await Navigator.push<int>(
        context, MaterialPageRoute(builder: (_) => const ClientFormScreen()));
    if (id != null) {
      _clients = await Db.i.clients();
      setState(() => _clientId = id);
    }
  }

  /// يفتح دليل المحاكم لاختيار جهة وكتابة اسمها في خانة المحكمة.
  Future<void> _pickCourt() async {
    final x = await Navigator.push<Court>(
        context, MaterialPageRoute(builder: (_) => const CourtsScreen(pick: true)));
    if (x != null) setState(() => _court.text = x.name);
  }

  Future<void> _pickPoaDate(bool expiry) async {
    final cur = expiry ? _poaExpiry : _poaDate;
    final x = await showDatePicker(
      context: context,
      initialDate: cur ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (x != null) setState(() => expiry ? _poaExpiry = dayStart(x) : _poaDate = dayStart(x));
  }

  Widget _dateTile(String label, DateTime? v, bool expiry) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _pickPoaDate(expiry),
            child: InputDecorator(
              decoration: dec(label, icon: Icons.event).copyWith(
                suffixIcon: v == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => expiry ? _poaExpiry = null : _poaDate = null),
                      ),
              ),
              child: Text(v == null ? '—' : fmtShort(v)),
            ),
          ),
        ),
      );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final c = _orig ?? LegalCase();
    c
      ..number = _number.text.trim()
      ..year = _year.text.trim()
      ..circuit = _circuit.text.trim()
      ..court = _court.text.trim()
      ..opponent = _opponent.text.trim()
      ..title = _title.text.trim()
      ..notes = _notes.text.trim()
      ..clientRole = _role
      ..type = _type
      ..status = _status
      ..clientId = _clientId
      ..poaNo = _poaNo.text.trim()
      ..poaKind = _poaKind
      ..poaOffice = _poaOffice.text.trim()
      ..poaPrincipal = _poaPrincipal.text.trim()
      ..poaNotes = _poaNotes.text.trim()
      ..poaDate = _poaDate
      ..poaExpiry = _poaExpiry;
    final id = await Db.i.saveCase(c);
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.caseId == null ? 'قضية جديدة' : 'تعديل القضية'),
        actions: [IconButton(onPressed: _save, icon: const Icon(Icons.check), tooltip: 'حفظ')],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  Expanded(flex: 2, child: tf(_number, 'رقم القضية', type: TextInputType.number, required: true)),
                  const SizedBox(width: 10),
                  Expanded(child: tf(_year, 'السنة', type: TextInputType.number)),
                ]),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: tf(_court, 'المحكمة التابعة', icon: Icons.account_balance)),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 4),
                    child: IconButton(
                      tooltip: 'اختيار من دليل المحاكم',
                      icon: const Icon(Icons.list_alt),
                      onPressed: _pickCourt,
                    ),
                  ),
                ]),
                tf(_circuit, 'الدائرة', icon: Icons.meeting_room_outlined),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<int?>(
                        value: _clients.any((c) => c.id == _clientId) ? _clientId : null,
                        isExpanded: true,
                        decoration: dec('الموكل', icon: Icons.person_outline),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('— بدون —')),
                          for (final c in _clients) DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                        ],
                        onChanged: (v) => setState(() => _clientId = v),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                      onPressed: _newClient, icon: const Icon(Icons.person_add_alt), tooltip: 'موكل جديد'),
                ]),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: _role,
                    decoration: dec('صفة الموكل في الدعوى'),
                    items: [for (final r in clientRoles) DropdownMenuItem(value: r, child: Text(r))],
                    onChanged: (v) => setState(() => _role = v!),
                  ),
                ),
                tf(_opponent, 'الخصم', icon: Icons.person_off_outlined),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    decoration: dec('نوع القضية'),
                    items: [for (final t in caseTypes) DropdownMenuItem(value: t, child: Text(t))],
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    decoration: dec('حالة القضية'),
                    items: [
                      for (final e in caseStatuses.entries) DropdownMenuItem(value: e.key, child: Text(e.value))
                    ],
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                ),
                tf(_title, 'موضوع الدعوى', icon: Icons.subject),
                tf(_notes, 'ملاحظات', maxLines: 5),
                Card(
                  child: ExpansionTile(
                    initiallyExpanded: _poaNo.text.isNotEmpty,
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('بيانات التوكيل'),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    children: [
                      tf(_poaNo, 'رقم التوكيل وسنته (مثال: 1234/2025 ج)', icon: Icons.tag),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          value: poaKinds.contains(_poaKind) ? _poaKind : '',
                          decoration: dec('نوع التوكيل'),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('— بدون —')),
                            for (final k in poaKinds) DropdownMenuItem(value: k, child: Text(k)),
                          ],
                          onChanged: (v) => setState(() => _poaKind = v ?? ''),
                        ),
                      ),
                      tf(_poaOffice, 'جهة التوثيق (الشهر العقاري / القنصلية ...)', icon: Icons.account_balance_outlined),
                      Row(children: [
                        _dateTile('تاريخ التحرير', _poaDate, false),
                        const SizedBox(width: 10),
                        _dateTile('تاريخ الانتهاء', _poaExpiry, true),
                      ]),
                      tf(_poaPrincipal, 'الموكِّل بالتوكيل (لو مختلف عن الموكل)', icon: Icons.person_outline),
                      tf(_poaNotes, 'حدود التوكيل وملاحظات (يشمل الصلح، الطعن ...)', maxLines: 3),
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text('صورة التوكيل: أضفها من تبويب «المستندات» داخل القضية.',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 8),
                FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('حفظ')),
              ]),
            ),
    );
  }
}
