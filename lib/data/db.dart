import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/utils.dart';
import 'models.dart';
import 'seed_templates.dart';

/// Stores attachment files inside the app's private documents directory.
class AppFiles {
  static late Directory dir;

  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    dir = Directory(p.join(docs.path, 'attachments'));
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  static File resolve(String name) => File(p.join(dir.path, name));

  static Future<String> saveCopy(String sourcePath) async {
    final name = '${DateTime.now().microsecondsSinceEpoch}${p.extension(sourcePath)}';
    await File(sourcePath).copy(p.join(dir.path, name));
    return name;
  }

  static Future<void> deleteFile(String name) async {
    try {
      final f = resolve(name);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

class Db extends ChangeNotifier {
  Db._();
  static final Db i = Db._();

  Database? _db;
  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'lawyer_agenda.db');
    return openDatabase(
      path,
      version: 10,
      onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON'),
      onOpen: (d) async {
        // إصلاح روابط التأجيل اليتيمة (جلسة تالية محذوفة)
        await d.execute('UPDATE sessions SET next_session_id=NULL WHERE next_session_id IS NOT NULL '
            'AND next_session_id NOT IN (SELECT id FROM sessions)');
      },
      onUpgrade: (d, oldV, newV) async {
        if (oldV < 2) await _v2(d);
        if (oldV < 3) await _v3(d);
        if (oldV < 4) await _v4(d);
        if (oldV < 5) await _v5(d);
        if (oldV < 6) await _v6(d);
        if (oldV < 7) await _v7(d);
        if (oldV < 8) await _v8(d);
        if (oldV < 9) await _v9(d);
        if (oldV < 10) await _v10(d);
      },
      onCreate: (d, v) async {
        await d.execute('''CREATE TABLE clients(
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT, address TEXT,
          national_id TEXT, notes TEXT)''');
        await d.execute('''CREATE TABLE cases(
          id INTEGER PRIMARY KEY AUTOINCREMENT, number TEXT, year TEXT, circuit TEXT, court TEXT,
          client_id INTEGER REFERENCES clients(id) ON DELETE SET NULL,
          client_role TEXT, opponent TEXT, type TEXT, status TEXT, title TEXT, notes TEXT,
          created_at INTEGER)''');
        await d.execute('''CREATE TABLE sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          case_id INTEGER NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
          date INTEGER NOT NULL, type TEXT, decision TEXT, notes TEXT, next_session_id INTEGER)''');
        await d.execute('''CREATE TABLE history(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          case_id INTEGER NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
          date INTEGER NOT NULL, text TEXT)''');
        await d.execute('''CREATE TABLE attachments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          case_id INTEGER NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
          session_id INTEGER REFERENCES sessions(id) ON DELETE SET NULL,
          file TEXT NOT NULL, created_at INTEGER)''');
        await d.execute('''CREATE TABLE payments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
          case_id INTEGER REFERENCES cases(id) ON DELETE SET NULL,
          kind TEXT NOT NULL, amount REAL NOT NULL, date INTEGER NOT NULL, note TEXT)''');
        await d.execute('''CREATE TABLE templates(
          id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, category TEXT, body TEXT)''');
        await d.execute('CREATE INDEX idx_sessions_date ON sessions(date)');
        await d.execute('CREATE INDEX idx_sessions_case ON sessions(case_id)');
        for (final t in seedTemplates) {
          await d.insert('templates', t);
        }
        await _v2(d);
        await _v3(d);
        await _v4(d);
        await _v5(d);
        await _v6(d);
        await _v7(d);
        await _v8(d);
        await _v9(d);
        await _v10(d);
      },
    );
  }

  /// الإصدار 2: المذكرات، المواعيد العامة، وإيميل الموكل.
  Future<void> _v2(Database d) async {
    await d.execute('ALTER TABLE clients ADD COLUMN email TEXT');
    await d.execute('''CREATE TABLE documents(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      case_id INTEGER NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
      title TEXT NOT NULL, category TEXT, body TEXT, created_at INTEGER, updated_at INTEGER)''');
    await d.execute('''CREATE TABLE appointments(
      id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, notes TEXT,
      date INTEGER NOT NULL, minutes INTEGER,
      case_id INTEGER REFERENCES cases(id) ON DELETE SET NULL)''');
    await d.execute('CREATE INDEX idx_documents_case ON documents(case_id)');
    await d.execute('CREATE INDEX idx_appointments_date ON appointments(date)');
  }

  /// الإصدار 3: ملفات المكتبة (PDF / Word).
  Future<void> _v3(Database d) async {
    await d.execute('''CREATE TABLE library_files(
      id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, category TEXT, note TEXT,
      file TEXT NOT NULL, ext TEXT, size INTEGER, created_at INTEGER)''');
  }

  /// الإصدار 4: دليل المحاكم (الوصول إليه من features/courts_directory/data/courts_repo.dart).
  Future<void> _v4(Database d) async {
    await d.execute('''CREATE TABLE courts(
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, kind TEXT, governorate TEXT,
      address TEXT, phone TEXT, map_url TEXT, jurisdiction TEXT, notes TEXT, created_at INTEGER)''');
  }

  /// الإصدار 5: نوع الموعد/الميعاد القانوني + مرجع ومبدأ لملفات المكتبة.
  Future<void> _v5(Database d) async {
    await d.execute("ALTER TABLE appointments ADD COLUMN kind TEXT DEFAULT 'other'");
    await d.execute('''CREATE TABLE links(
      id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, url TEXT NOT NULL,
      category TEXT, note TEXT, created_at INTEGER)''');
    // روابط رسمية معروفة كبداية، قابلة للتعديل والحذف (راجع صحتها).
    const seed = [
      ['وزارة العدل', 'https://www.moj.gov.eg'],
      ['النيابة العامة', 'https://www.ppo.gov.eg'],
      ['محكمة النقض', 'https://www.cc.gov.eg'],
      ['مجلس الدولة', 'https://www.ecs.gov.eg'],
      ['المحكمة الدستورية العليا', 'https://www.sccourt.gov.eg'],
      ['البوابة الحكومية المصرية', 'https://www.egypt.gov.eg'],
    ];
    for (final s in seed) {
      await d.insert('links', {
        'title': s[0],
        'url': s[1],
        'category': 'المحاكم والجهات الرسمية',
        'note': '',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await d.execute('ALTER TABLE sessions ADD COLUMN roll TEXT');
    await d.execute('ALTER TABLE library_files ADD COLUMN ref TEXT');
    await d.execute('ALTER TABLE library_files ADD COLUMN principle TEXT');
  }

  /// الإصدار 6: تنبيه مخصص (تاريخ ووقت) لكل جلسة وموعد.
  Future<void> _v6(Database d) async {
    await d.execute('ALTER TABLE sessions ADD COLUMN remind_at INTEGER');
    await d.execute('ALTER TABLE appointments ADD COLUMN remind_at INTEGER');
  }

  /// الإصدار 7: أرشفة القضايا.
  Future<void> _v7(Database d) async {
    await d.execute('ALTER TABLE cases ADD COLUMN archived INTEGER DEFAULT 0');
  }

  /// الإصدار 8: الالتزامات الشخصية (ديون، إيجارات، أقساط، فواتير) ومدفوعاتها.
  Future<void> _v8(Database d) async {
    await d.execute('''CREATE TABLE obligations(
      id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, title TEXT NOT NULL, party TEXT, phone TEXT,
      notes TEXT, amount REAL NOT NULL DEFAULT 0, paid REAL NOT NULL DEFAULT 0, due INTEGER,
      repeat TEXT DEFAULT 'none', status TEXT DEFAULT 'open', remind_at INTEGER, created_at INTEGER)''');
    await d.execute('''CREATE TABLE obligation_payments(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      obligation_id INTEGER NOT NULL REFERENCES obligations(id) ON DELETE CASCADE,
      amount REAL NOT NULL, date INTEGER NOT NULL, note TEXT)''');
    await d.execute('CREATE INDEX idx_obl_due ON obligations(due)');
  }

  /// الإصدار 9: بيانات التوكيل في القضية.
  Future<void> _v9(Database d) async {
    for (final c in const [
      'poa_no TEXT', 'poa_kind TEXT', 'poa_office TEXT', 'poa_principal TEXT', 'poa_notes TEXT',
      'poa_date INTEGER', 'poa_expiry INTEGER',
    ]) {
      await d.execute('ALTER TABLE cases ADD COLUMN $c');
    }
  }

  /// الإصدار 10: رابط القرارات (من باركود المحكمة) في دليل المحاكم.
  Future<void> _v10(Database d) async {
    await d.execute('ALTER TABLE courts ADD COLUMN decisions_url TEXT');
  }

  // ---------- generic ----------
  Future<int> _save(String table, Map<String, Object?> m) async {
    final d = await db;
    final id = m['id'];
    int result;
    if (id == null) {
      m.remove('id');
      result = await d.insert(table, m);
    } else {
      await d.update(table, m, where: 'id=?', whereArgs: [id]);
      result = id as int;
    }
    notifyListeners();
    return result;
  }

  Future<void> _delete(String table, int id) async {
    final d = await db;
    await d.delete(table, where: 'id=?', whereArgs: [id]);
    notifyListeners();
  }

  // ---------- clients ----------
  Future<List<Client>> clients({String? q}) async {
    final d = await db;
    final args = <Object?>[];
    var where = '';
    if (q != null && q.trim().isNotEmpty) {
      where = 'WHERE name LIKE ? OR phone LIKE ? OR national_id LIKE ?';
      final l = '%${q.trim()}%';
      args.addAll([l, l, l]);
    }
    final rows = await d.rawQuery(
        'SELECT c.*, (SELECT COUNT(*) FROM cases x WHERE x.client_id=c.id) AS cases_count '
        'FROM clients c $where ORDER BY name COLLATE NOCASE',
        args);
    return rows.map(Client.fromMap).toList();
  }

  Future<Client?> client(int id) async {
    final d = await db;
    final r = await d.query('clients', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : Client.fromMap(r.first);
  }

  Future<int> saveClient(Client c) => _save('clients', c.toMap());
  Future<void> deleteClient(int id) => _delete('clients', id);

  // ---------- cases ----------
  /// [archived]: null = الكل، false = غير المؤرشفة، true = المؤرشفة فقط.
  Future<List<LegalCase>> cases({String? status, String? q, String? type, int? clientId, bool? archived}) async {
    final d = await db;
    final where = <String>[];
    final args = <Object?>[dayStart(DateTime.now()).millisecondsSinceEpoch];
    if (status != null) {
      where.add('c.status=?');
      args.add(status);
    }
    if (archived != null) {
      where.add(archived ? 'IFNULL(c.archived,0)=1' : 'IFNULL(c.archived,0)=0');
    }
    if (type != null) {
      where.add('c.type=?');
      args.add(type);
    }
    if (clientId != null) {
      where.add('c.client_id=?');
      args.add(clientId);
    }
    if (q != null && q.trim().isNotEmpty) {
      where.add('(c.number LIKE ? OR c.year LIKE ? OR cl.name LIKE ? OR c.opponent LIKE ? '
          'OR c.court LIKE ? OR c.title LIKE ?)');
      final l = '%${q.trim()}%';
      args.addAll([l, l, l, l, l, l]);
    }
    final rows = await d.rawQuery(
        'SELECT * FROM (SELECT c.*, cl.name AS client_name, '
        '(SELECT MIN(s.date) FROM sessions s WHERE s.case_id=c.id AND s.date>=? AND s.next_session_id IS NULL) AS next_date '
        'FROM cases c LEFT JOIN clients cl ON cl.id=c.client_id '
        '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}) '
        'ORDER BY (next_date IS NULL), next_date, created_at DESC',
        args);
    return rows.map(LegalCase.fromMap).toList();
  }

  Future<LegalCase?> legalCase(int id) async {
    final d = await db;
    final r = await d.rawQuery(
        'SELECT c.*, cl.name AS client_name FROM cases c '
        'LEFT JOIN clients cl ON cl.id=c.client_id WHERE c.id=?',
        [id]);
    return r.isEmpty ? null : LegalCase.fromMap(r.first);
  }

  Future<int> saveCase(LegalCase c) => _save('cases', c.toMap());

  Future<void> setCaseArchived(int id, bool v) async {
    final d = await db;
    await d.update('cases', {'archived': v ? 1 : 0}, where: 'id=?', whereArgs: [id]);
    notifyListeners();
  }

  /// قضايا جارية/مؤجلة وغير مؤرشفة بدون أي جلسة قادمة (تحتاج انتباه).
  Future<List<LegalCase>> casesWithoutNextSession() async {
    final all = await cases(archived: false);
    return all.where((c) => c.nextDate == null && (c.status == 'active' || c.status == 'postponed')).toList();
  }

  /// أرصدة الموكلين: الأتعاب المتفق عليها والمدفوع والمتبقي (للمتأخرات).
  Future<List<ClientBalance>> clientBalances() async {
    final d = await db;
    final rows = await d.rawQuery('SELECT client_id, kind, SUM(amount) AS t FROM payments GROUP BY client_id, kind');
    final fee = <int, double>{}, paid = <int, double>{};
    for (final r in rows) {
      final id = (r['client_id'] as num).toInt();
      final t = (r['t'] as num?)?.toDouble() ?? 0;
      if (r['kind'] == 'fee') fee[id] = t;
      if (r['kind'] == 'payment') paid[id] = t;
    }
    final cl = await clients();
    return [for (final c in cl) ClientBalance(c, fee[c.id] ?? 0, paid[c.id] ?? 0)];
  }

  Future<void> setCaseStatus(int id, String status) async {
    final d = await db;
    await d.update('cases', {'status': status}, where: 'id=?', whereArgs: [id]);
    notifyListeners();
  }

  Future<void> deleteCase(int id) async {
    final d = await db;
    final files = await d.query('attachments', where: 'case_id=?', whereArgs: [id]);
    for (final f in files) {
      await AppFiles.deleteFile(f['file'] as String);
    }
    await d.delete('cases', where: 'id=?', whereArgs: [id]);
    notifyListeners();
  }

  Future<Map<String, int>> counts() async {
    final d = await db;
    final rows = await d.rawQuery('SELECT status, COUNT(*) AS n FROM cases WHERE IFNULL(archived,0)=0 GROUP BY status');
    return {for (final r in rows) r['status'] as String: (r['n'] as num).toInt()};
  }

  // ---------- sessions ----------
  static const _sessSel =
      'SELECT s.*, c.number AS case_number, c.year AS case_year, c.court AS court, '
      'c.title AS case_title, cl.name AS client_name FROM sessions s '
      'JOIN cases c ON c.id=s.case_id LEFT JOIN clients cl ON cl.id=c.client_id';

  Future<List<CaseSession>> sessions({
    int? caseId,
    DateTime? from,
    DateTime? to,
    bool overdueNoDecision = false,
    bool desc = false,
    int? limit,
  }) async {
    final d = await db;
    final where = <String>[];
    final args = <Object?>[];
    if (caseId != null) {
      where.add('s.case_id=?');
      args.add(caseId);
    }
    if (from != null) {
      where.add('s.date>=?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('s.date<?');
      args.add(to.millisecondsSinceEpoch);
    }
    if (overdueNoDecision) {
      where.add("TRIM(IFNULL(s.decision,''))='' AND c.status IN ('active','postponed')");
    }
    final rows = await d.rawQuery(
        '$_sessSel ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
        'ORDER BY s.date ${desc ? 'DESC' : 'ASC'}${limit != null ? ' LIMIT $limit' : ''}',
        args);
    return rows.map(CaseSession.fromMap).toList();
  }

  Future<CaseSession?> session(int id) async {
    final d = await db;
    final r = await d.rawQuery('$_sessSel WHERE s.id=?', [id]);
    return r.isEmpty ? null : CaseSession.fromMap(r.first);
  }

  /// Saves a session. When [next] is provided, a follow-up session is created
  /// automatically (or the previously linked one is updated).
  Future<int> saveSession(CaseSession s,
      {DateTime? next, String nextType = 'pleading', String nextRoll = ''}) async {
    final d = await db;
    late int sid;
    await d.transaction((txn) async {
      int? nextId = s.nextSessionId;
      if (next != null) {
        final nd = dayStart(next).millisecondsSinceEpoch;
        var updated = 0;
        if (nextId != null) {
          updated = await txn.update('sessions', {'date': nd, 'type': nextType, 'roll': nextRoll},
              where: 'id=?', whereArgs: [nextId]);
        }
        // لو لا توجد جلسة تالية، أو كانت محذوفة (معرّف يتيم)، تُنشأ جلسة جديدة بدل أن يضيع التأجيل.
        if (updated == 0) {
          nextId = await txn.insert('sessions', {
            'case_id': s.caseId,
            'date': nd,
            'type': nextType,
            'roll': nextRoll,
            'decision': '',
            'notes': '',
          });
        }
      }
      final m = s.toMap();
      m['date'] = dayStart(s.date).millisecondsSinceEpoch;
      m['next_session_id'] = nextId;
      if (s.id == null) {
        m.remove('id');
        sid = await txn.insert('sessions', m);
      } else {
        await txn.update('sessions', m, where: 'id=?', whereArgs: [s.id]);
        sid = s.id!;
      }
    });
    notifyListeners();
    return sid;
  }

  Future<void> deleteSession(int id) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.update('sessions', {'next_session_id': null}, where: 'next_session_id=?', whereArgs: [id]);
      await txn.delete('sessions', where: 'id=?', whereArgs: [id]);
    });
    notifyListeners();
  }

  /// جلسات أخرى في نفس اليوم ونفس المحكمة (لتحذير التعارض).
  Future<List<CaseSession>> sameDayCourtSessions(DateTime day, String court, int excludeCaseId) async {
    if (court.trim().isEmpty) return [];
    final t = dayStart(day);
    final all = await sessions(from: t, to: addDays(t, 1));
    return all.where((s) => s.caseId != excludeCaseId && s.court.trim() == court.trim()).toList();
  }

  // ---------- دمج الموكلين المكررين ----------
  static String _normName(String s) => s
      .replaceAll(RegExp(r'[\u064B-\u0652\u0640]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();

  /// مجموعات الموكلين بنفس الاسم (بعد توحيد الهمزات والمسافات)؛ كل مجموعة فيها سجلان أو أكثر.
  Future<List<List<Client>>> duplicateClientGroups() async {
    final all = await clients();
    final map = <String, List<Client>>{};
    for (final c in all) {
      final k = _normName(c.name);
      if (k.isEmpty) continue;
      map.putIfAbsent(k, () => []).add(c);
    }
    return map.values.where((l) => l.length > 1).toList();
  }

  /// يدمج المجموعة في سجل واحد (الأكثر قضايا)، وينقل القضايا والدفعات، ويكمّل البيانات الناقصة، ويحذف الباقي.
  Future<void> mergeClientGroup(List<Client> group) async {
    final d = await db;
    final sorted = [...group]..sort((a, b) => b.casesCount.compareTo(a.casesCount));
    final keep = sorted.first;
    await d.transaction((txn) async {
      final fill = <String, Object?>{};
      for (final o in sorted.skip(1)) {
        if (keep.phone.isEmpty && o.phone.isNotEmpty) fill['phone'] = keep.phone = o.phone;
        if (keep.email.isEmpty && o.email.isNotEmpty) fill['email'] = keep.email = o.email;
        if (keep.address.isEmpty && o.address.isNotEmpty) fill['address'] = keep.address = o.address;
        if (keep.nationalId.isEmpty && o.nationalId.isNotEmpty) fill['national_id'] = keep.nationalId = o.nationalId;
        if (o.notes.trim().isNotEmpty && !keep.notes.contains(o.notes.trim())) {
          keep.notes = keep.notes.isEmpty ? o.notes : '${keep.notes}\n${o.notes}';
          fill['notes'] = keep.notes;
        }
        await txn.update('cases', {'client_id': keep.id}, where: 'client_id=?', whereArgs: [o.id]);
        await txn.update('payments', {'client_id': keep.id}, where: 'client_id=?', whereArgs: [o.id]);
        await txn.delete('clients', where: 'id=?', whereArgs: [o.id]);
      }
      if (fill.isNotEmpty) await txn.update('clients', fill, where: 'id=?', whereArgs: [keep.id]);
    });
    notifyListeners();
  }

  // ---------- history ----------
  Future<List<HistoryEntry>> history(int caseId) async {
    final d = await db;
    final r = await d.query('history', where: 'case_id=?', whereArgs: [caseId], orderBy: 'date DESC, id DESC');
    return r.map(HistoryEntry.fromMap).toList();
  }

  Future<int> saveHistory(HistoryEntry h) => _save('history', h.toMap());
  Future<void> deleteHistory(int id) => _delete('history', id);

  // ---------- attachments ----------
  Future<List<Attachment>> attachments(int caseId, {int? sessionId}) async {
    final d = await db;
    final r = await d.query('attachments',
        where: sessionId == null ? 'case_id=?' : 'case_id=? AND session_id=?',
        whereArgs: sessionId == null ? [caseId] : [caseId, sessionId],
        orderBy: 'created_at DESC');
    return r.map(Attachment.fromMap).toList();
  }

  Future<int> saveAttachment(Attachment a) => _save('attachments', a.toMap());

  Future<void> deleteAttachment(Attachment a) async {
    await AppFiles.deleteFile(a.file);
    await _delete('attachments', a.id!);
  }

  // ---------- payments ----------
  Future<List<Payment>> payments(int clientId) async {
    final d = await db;
    final r = await d.rawQuery(
        "SELECT p.*, CASE WHEN c.id IS NULL THEN '' ELSE ('قضية ' || c.number || '/' || c.year) END AS case_label "
        'FROM payments p LEFT JOIN cases c ON c.id=p.case_id WHERE p.client_id=? '
        'ORDER BY p.date DESC, p.id DESC',
        [clientId]);
    return r.map(Payment.fromMap).toList();
  }

  /// Returns {'fees': total agreed, 'paid': total paid}.
  Future<Map<String, double>> totals(int clientId) async {
    final d = await db;
    final r = await d.rawQuery(
        'SELECT kind, SUM(amount) AS t FROM payments WHERE client_id=? GROUP BY kind', [clientId]);
    double fees = 0, paid = 0;
    for (final row in r) {
      final t = (row['t'] as num?)?.toDouble() ?? 0;
      if (row['kind'] == 'fee') fees = t;
      if (row['kind'] == 'payment') paid = t;
    }
    return {'fees': fees, 'paid': paid};
  }

  Future<int> savePayment(Payment p) => _save('payments', p.toMap());
  Future<void> deletePayment(int id) => _delete('payments', id);

  // ---------- templates ----------
  Future<List<LegalTemplate>> templates({String? q, String? category}) async {
    final d = await db;
    final where = <String>[];
    final args = <Object?>[];
    if (category != null) {
      where.add('category=?');
      args.add(category);
    }
    if (q != null && q.trim().isNotEmpty) {
      where.add('(title LIKE ? OR body LIKE ?)');
      final l = '%${q.trim()}%';
      args.addAll([l, l]);
    }
    final r = await d.query('templates',
        where: where.isEmpty ? null : where.join(' AND '), whereArgs: args, orderBy: 'category, title');
    return r.map(LegalTemplate.fromMap).toList();
  }

  Future<int> saveTemplate(LegalTemplate t) => _save('templates', t.toMap());
  Future<void> deleteTemplate(int id) => _delete('templates', id);

  // ---------- v3: ملفات المكتبة ----------
  Future<List<LibraryFile>> libraryFiles({String? q, String? category}) async {
    final d = await db;
    final where = <String>[];
    final args = <Object?>[];
    if (category != null) {
      where.add('category=?');
      args.add(category);
    }
    if (q != null && q.trim().isNotEmpty) {
      where.add('(title LIKE ? OR note LIKE ? OR ref LIKE ? OR principle LIKE ?)');
      final l = '%${q.trim()}%';
      args.addAll([l, l, l, l]);
    }
    final r = await d.query('library_files',
        where: where.isEmpty ? null : where.join(' AND '), whereArgs: args, orderBy: 'created_at DESC');
    return r.map(LibraryFile.fromMap).toList();
  }

  Future<LibraryFile?> libraryFile(int id) async {
    final d = await db;
    final r = await d.query('library_files', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : LibraryFile.fromMap(r.first);
  }

  Future<int> saveLibraryFile(LibraryFile f) => _save('library_files', f.toMap());

  Future<void> deleteLibraryFile(LibraryFile f) async {
    await AppFiles.deleteFile(f.file);
    await _delete('library_files', f.id!);
  }

  // ---------- v2: الماليات حسب النوع ----------
  Future<Map<String, double>> _kindTotals(String where, List<Object?> args) async {
    final d = await db;
    final r = await d.rawQuery(
        'SELECT kind, SUM(amount) AS t FROM payments WHERE $where GROUP BY kind', args);
    final m = <String, double>{for (final k in moneyKinds.keys) k: 0.0};
    for (final row in r) {
      m[row['kind'] as String] = (row['t'] as num?)?.toDouble() ?? 0;
    }
    return m;
  }

  /// مجاميع الأنواع الأربعة (fee, payment, deposit, expense).
  Future<Map<String, double>> clientTotals(int clientId) => _kindTotals('client_id=?', [clientId]);
  Future<Map<String, double>> caseTotals(int caseId) => _kindTotals('case_id=?', [caseId]);
  Future<Map<String, double>> overallTotals() => _kindTotals('1=1', []);

  Future<List<Payment>> paymentsForCase(int caseId) async {
    final d = await db;
    final r = await d.rawQuery(
        "SELECT p.*, CASE WHEN c.id IS NULL THEN '' ELSE ('قضية ' || c.number || '/' || c.year) END AS case_label "
        'FROM payments p LEFT JOIN cases c ON c.id=p.case_id WHERE p.case_id=? '
        'ORDER BY p.date DESC, p.id DESC',
        [caseId]);
    return r.map(Payment.fromMap).toList();
  }

  // ---------- v2: المذكرات والمستندات النصية ----------
  Future<List<CaseDocument>> documents(int caseId, {String? category, String? q}) async {
    final d = await db;
    final where = <String>['case_id=?'];
    final args = <Object?>[caseId];
    if (category != null) {
      where.add('category=?');
      args.add(category);
    }
    if (q != null && q.trim().isNotEmpty) {
      where.add('(title LIKE ? OR body LIKE ?)');
      final l = '%${q.trim()}%';
      args.addAll([l, l]);
    }
    final r = await d.query('documents',
        where: where.join(' AND '), whereArgs: args, orderBy: 'updated_at DESC');
    return r.map(CaseDocument.fromMap).toList();
  }

  Future<CaseDocument?> document(int id) async {
    final d = await db;
    final r = await d.query('documents', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : CaseDocument.fromMap(r.first);
  }

  Future<int> saveDocument(CaseDocument x) {
    x.updatedAt = DateTime.now().millisecondsSinceEpoch;
    return _save('documents', x.toMap());
  }

  Future<void> deleteDocument(int id) => _delete('documents', id);

  // ---------- v2: المواعيد العامة ----------
  Future<List<Appointment>> appointments({DateTime? from, DateTime? to, int? caseId}) async {
    final d = await db;
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('a.date>=?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('a.date<?');
      args.add(to.millisecondsSinceEpoch);
    }
    if (caseId != null) {
      where.add('a.case_id=?');
      args.add(caseId);
    }
    final r = await d.rawQuery(
        "SELECT a.*, CASE WHEN c.id IS NULL THEN '' ELSE ('قضية ' || c.number || '/' || c.year) END AS case_label "
        'FROM appointments a LEFT JOIN cases c ON c.id=a.case_id '
        '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
        'ORDER BY a.date, IFNULL(a.minutes, -1)',
        args);
    return r.map(Appointment.fromMap).toList();
  }

  Future<Appointment?> appointment(int id) async {
    final d = await db;
    final r = await d.query('appointments', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : Appointment.fromMap(r.first);
  }

  Future<int> saveAppointment(Appointment a) {
    a.date = dayStart(a.date);
    return _save('appointments', a.toMap());
  }

  Future<void> deleteAppointment(int id) => _delete('appointments', id);

  void changed() => notifyListeners();

  // ---------- obligations (الالتزامات الشخصية) ----------
  Future<List<Obligation>> obligations({bool? done}) async {
    final d = await db;
    final rows = await d.query('obligations',
        where: done == null ? null : 'status=?',
        whereArgs: done == null ? null : [done ? 'done' : 'open'],
        orderBy: done == true ? 'due DESC, id DESC' : 'CASE WHEN due IS NULL THEN 1 ELSE 0 END, due ASC, id DESC');
    return rows.map(Obligation.fromMap).toList();
  }

  Future<Obligation?> obligation(int id) async {
    final d = await db;
    final r = await d.query('obligations', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : Obligation.fromMap(r.first);
  }

  Future<int> saveObligation(Obligation o) {
    o.status = (o.amount > 0 && o.paid >= o.amount) ? 'done' : 'open';
    return _save('obligations', o.toMap());
  }

  Future<void> deleteObligation(int id) => _delete('obligations', id);

  Future<List<ObligationPayment>> obligationPayments(int id) async {
    final d = await db;
    final rows = await d.query('obligation_payments',
        where: 'obligation_id=?', whereArgs: [id], orderBy: 'date DESC, id DESC');
    return rows.map(ObligationPayment.fromMap).toList();
  }

  /// يسجّل دفعة. عند اكتمال المبلغ يُغلق الالتزام، ولو متكررًا يُنشأ الاستحقاق التالي تلقائيًا.
  Future<void> addObligationPayment(Obligation o, double amount, DateTime date, String note) async {
    final d = await db;
    await d.transaction((t) async {
      await t.insert('obligation_payments', {
        'obligation_id': o.id,
        'amount': amount,
        'date': date.millisecondsSinceEpoch,
        'note': note,
      });
      final paid = o.paid + amount;
      final wasOpen = !o.done;
      final nowDone = o.amount > 0 && paid >= o.amount;
      await t.update('obligations', {'paid': paid, 'status': nowDone ? 'done' : 'open'},
          where: 'id=?', whereArgs: [o.id]);
      if (wasOpen && nowDone && o.repeat != 'none' && o.due != null) {
        final next = o.repeat == 'yearly' ? addMonths(o.due!, 12) : addMonths(o.due!, 1);
        await t.insert('obligations', {
          'kind': o.kind,
          'title': o.title,
          'party': o.party,
          'phone': o.phone,
          'notes': o.notes,
          'amount': o.amount,
          'paid': 0,
          'due': next.millisecondsSinceEpoch,
          'repeat': o.repeat,
          'status': 'open',
          'remind_at': null,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
    notifyListeners();
  }

  /// حذف دفعة مسجّلة بالخطأ وإعادة حساب المسدّد.
  Future<void> deleteObligationPayment(ObligationPayment p) async {
    final d = await db;
    await d.transaction((t) async {
      await t.delete('obligation_payments', where: 'id=?', whereArgs: [p.id]);
      final r = await t.rawQuery(
          'SELECT COALESCE(SUM(amount),0) AS s FROM obligation_payments WHERE obligation_id=?', [p.obligationId]);
      final paid = (r.first['s'] as num).toDouble();
      final o = await t.query('obligations', where: 'id=?', whereArgs: [p.obligationId]);
      if (o.isEmpty) return;
      final amount = (o.first['amount'] as num).toDouble();
      await t.update('obligations', {'paid': paid, 'status': (amount > 0 && paid >= amount) ? 'done' : 'open'},
          where: 'id=?', whereArgs: [p.obligationId]);
    });
    notifyListeners();
  }

}

/// رصيد موكل: الأتعاب والمدفوع والمتبقي.
class ClientBalance {
  final Client client;
  final double fee, paid;
  ClientBalance(this.client, this.fee, this.paid);
  double get remaining => fee - paid;
}
