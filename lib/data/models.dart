import '../core/utils.dart';

String _s(Object? v) => (v as String?) ?? '';
int? _n(Object? v) => (v as num?)?.toInt();

class Client {
  int? id;
  String name, phone, email, address, nationalId, notes;
  int casesCount;
  Client({
    this.id,
    this.name = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.nationalId = '',
    this.notes = '',
    this.casesCount = 0,
  });
  factory Client.fromMap(Map<String, Object?> m) => Client(
        id: _n(m['id']),
        name: _s(m['name']),
        phone: _s(m['phone']),
        email: _s(m['email']),
        address: _s(m['address']),
        nationalId: _s(m['national_id']),
        notes: _s(m['notes']),
        casesCount: _n(m['cases_count']) ?? 0,
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'national_id': nationalId,
        'notes': notes,
      };
}

/// مذكرة / مستند نصي مرتبط بقضية (مسودة دفاع، طعن، ملاحظات عمل...).
class CaseDocument {
  int? id;
  int caseId;
  String title, category, body;
  int createdAt, updatedAt;
  CaseDocument({
    this.id,
    required this.caseId,
    this.title = '',
    this.category = 'مذكرة دفاع',
    this.body = '',
    int? createdAt,
    int? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;
  factory CaseDocument.fromMap(Map<String, Object?> m) => CaseDocument(
        id: _n(m['id']),
        caseId: _n(m['case_id'])!,
        title: _s(m['title']),
        category: _s(m['category']),
        body: _s(m['body']),
        createdAt: _n(m['created_at']),
        updatedAt: _n(m['updated_at']),
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'case_id': caseId,
        'title': title,
        'category': category,
        'body': body,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

/// موعد عام (اجتماع، سداد رسوم، استلام صورة...) غير مرتبط بجلسة بالضرورة.
class Appointment {
  int? id;
  String title, notes;
  DateTime date;
  int? minutes; // دقائق من منتصف الليل، null = طوال اليوم
  int? caseId;
  String caseLabelText;
  String kind; // مفتاح من appointmentKinds
  DateTime? remindAt; // تنبيه مخصص
  Appointment({
    this.id,
    this.title = '',
    this.notes = '',
    required this.date,
    this.minutes,
    this.caseId,
    this.caseLabelText = '',
    this.kind = 'other',
    this.remindAt,
  });
  factory Appointment.fromMap(Map<String, Object?> m) => Appointment(
        id: _n(m['id']),
        title: _s(m['title']),
        notes: _s(m['notes']),
        date: DateTime.fromMillisecondsSinceEpoch(_n(m['date'])!),
        minutes: _n(m['minutes']),
        caseId: _n(m['case_id']),
        caseLabelText: _s(m['case_label']),
        kind: _s(m['kind']).isEmpty ? 'other' : _s(m['kind']),
        remindAt: _n(m['remind_at']) == null ? null : DateTime.fromMillisecondsSinceEpoch(_n(m['remind_at'])!),
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'notes': notes,
        'date': date.millisecondsSinceEpoch,
        'minutes': minutes,
        'case_id': caseId,
        'kind': kind,
        'remind_at': remindAt?.millisecondsSinceEpoch,
      };
}

class LegalCase {
  int? id;
  String number, year, circuit, court, clientRole, opponent, type, status, title, notes;
  int? clientId;
  int createdAt;
  String clientName;
  bool archived;
  DateTime? nextDate;
  // بيانات التوكيل
  String poaNo, poaKind, poaOffice, poaPrincipal, poaNotes;
  DateTime? poaDate, poaExpiry;
  bool get hasPoa => poaNo.trim().isNotEmpty || poaKind.isNotEmpty || poaOffice.trim().isNotEmpty;
  LegalCase({
    this.id,
    this.number = '',
    this.year = '',
    this.circuit = '',
    this.court = '',
    this.clientId,
    this.clientRole = 'مدعي',
    this.opponent = '',
    this.type = 'مدني',
    this.status = 'active',
    this.title = '',
    this.notes = '',
    int? createdAt,
    this.clientName = '',
    this.archived = false,
    this.nextDate,
    this.poaNo = '',
    this.poaKind = '',
    this.poaOffice = '',
    this.poaPrincipal = '',
    this.poaNotes = '',
    this.poaDate,
    this.poaExpiry,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  factory LegalCase.fromMap(Map<String, Object?> m) => LegalCase(
        id: _n(m['id']),
        number: _s(m['number']),
        year: _s(m['year']),
        circuit: _s(m['circuit']),
        court: _s(m['court']),
        clientId: _n(m['client_id']),
        clientRole: _s(m['client_role']),
        opponent: _s(m['opponent']),
        type: _s(m['type']),
        status: _s(m['status']),
        title: _s(m['title']),
        notes: _s(m['notes']),
        createdAt: _n(m['created_at']),
        clientName: _s(m['client_name']),
        archived: _n(m['archived']) == 1,
        poaNo: _s(m['poa_no']),
        poaKind: _s(m['poa_kind']),
        poaOffice: _s(m['poa_office']),
        poaPrincipal: _s(m['poa_principal']),
        poaNotes: _s(m['poa_notes']),
        poaDate: _n(m['poa_date']) == null ? null : DateTime.fromMillisecondsSinceEpoch(_n(m['poa_date'])!),
        poaExpiry: _n(m['poa_expiry']) == null ? null : DateTime.fromMillisecondsSinceEpoch(_n(m['poa_expiry'])!),
        nextDate: _n(m['next_date']) == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(_n(m['next_date'])!),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'number': number,
        'year': year,
        'circuit': circuit,
        'court': court,
        'client_id': clientId,
        'client_role': clientRole,
        'opponent': opponent,
        'type': type,
        'status': status,
        'title': title,
        'notes': notes,
        'archived': archived ? 1 : 0,
        'poa_no': poaNo,
        'poa_kind': poaKind,
        'poa_office': poaOffice,
        'poa_principal': poaPrincipal,
        'poa_notes': poaNotes,
        'poa_date': poaDate?.millisecondsSinceEpoch,
        'poa_expiry': poaExpiry?.millisecondsSinceEpoch,
        'created_at': createdAt,
      };
}

class CaseSession {
  int? id;
  int caseId;
  DateTime date;
  String type, decision, notes;
  String roll; // رقم الرول
  DateTime? remindAt; // تنبيه مخصص يحل محل التنبيهين الافتراضيين
  int? nextSessionId;
  // joined info
  String caseNumber, caseYear, court, clientName, caseTitle;
  CaseSession({
    this.id,
    required this.caseId,
    required this.date,
    this.type = 'pleading',
    this.decision = '',
    this.notes = '',
    this.roll = '',
    this.remindAt,
    this.nextSessionId,
    this.caseNumber = '',
    this.caseYear = '',
    this.court = '',
    this.clientName = '',
    this.caseTitle = '',
  });
  factory CaseSession.fromMap(Map<String, Object?> m) => CaseSession(
        id: _n(m['id']),
        caseId: _n(m['case_id'])!,
        date: DateTime.fromMillisecondsSinceEpoch(_n(m['date'])!),
        type: _s(m['type']),
        decision: _s(m['decision']),
        notes: _s(m['notes']),
        roll: _s(m['roll']),
        remindAt: _n(m['remind_at']) == null ? null : DateTime.fromMillisecondsSinceEpoch(_n(m['remind_at'])!),
        nextSessionId: _n(m['next_session_id']),
        caseNumber: _s(m['case_number']),
        caseYear: _s(m['case_year']),
        court: _s(m['court']),
        clientName: _s(m['client_name']),
        caseTitle: _s(m['case_title']),
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'case_id': caseId,
        'date': date.millisecondsSinceEpoch,
        'type': type,
        'decision': decision,
        'notes': notes,
        'roll': roll,
        'remind_at': remindAt?.millisecondsSinceEpoch,
        'next_session_id': nextSessionId,
      };
}

class HistoryEntry {
  int? id;
  int caseId;
  DateTime date;
  String text;
  HistoryEntry({this.id, required this.caseId, required this.date, required this.text});
  factory HistoryEntry.fromMap(Map<String, Object?> m) => HistoryEntry(
        id: _n(m['id']),
        caseId: _n(m['case_id'])!,
        date: DateTime.fromMillisecondsSinceEpoch(_n(m['date'])!),
        text: _s(m['text']),
      );
  Map<String, Object?> toMap() =>
      {'id': id, 'case_id': caseId, 'date': date.millisecondsSinceEpoch, 'text': text};
}

class Attachment {
  int? id;
  int caseId;
  int? sessionId;
  String file; // file name inside the app attachments folder
  int createdAt;
  Attachment({this.id, required this.caseId, this.sessionId, required this.file, int? createdAt})
      : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;
  factory Attachment.fromMap(Map<String, Object?> m) => Attachment(
        id: _n(m['id']),
        caseId: _n(m['case_id'])!,
        sessionId: _n(m['session_id']),
        file: _s(m['file']),
        createdAt: _n(m['created_at']),
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'case_id': caseId,
        'session_id': sessionId,
        'file': file,
        'created_at': createdAt,
      };
}

class Payment {
  int? id;
  int clientId;
  int? caseId;
  String kind; // 'fee' | 'payment'
  double amount;
  DateTime date;
  String note;
  String caseLabelText;
  Payment({
    this.id,
    required this.clientId,
    this.caseId,
    this.kind = 'payment',
    this.amount = 0,
    required this.date,
    this.note = '',
    this.caseLabelText = '',
  });
  factory Payment.fromMap(Map<String, Object?> m) => Payment(
        id: _n(m['id']),
        clientId: _n(m['client_id'])!,
        caseId: _n(m['case_id']),
        kind: _s(m['kind']),
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        date: DateTime.fromMillisecondsSinceEpoch(_n(m['date'])!),
        note: _s(m['note']),
        caseLabelText: _s(m['case_label']),
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'client_id': clientId,
        'case_id': caseId,
        'kind': kind,
        'amount': amount,
        'date': date.millisecondsSinceEpoch,
        'note': note,
      };
}

class LegalTemplate {
  int? id;
  String title, category, body;
  LegalTemplate({this.id, this.title = '', this.category = 'أخرى', this.body = ''});
  factory LegalTemplate.fromMap(Map<String, Object?> m) => LegalTemplate(
        id: _n(m['id']),
        title: _s(m['title']),
        category: _s(m['category']),
        body: _s(m['body']),
      );
  Map<String, Object?> toMap() => {'id': id, 'title': title, 'category': category, 'body': body};
}

/// ملف (PDF / Word) مرفوع إلى المكتبة. الملف نفسه داخل مجلد التطبيق الخاص.
class LibraryFile {
  int? id;
  String title, category, note;
  String ref, principle; // رقم الطعن/المرجع + المبدأ
  String file; // اسم الملف داخل مجلد AppFiles
  String ext; // pdf | doc | docx
  int size; // بالبايت
  int createdAt;
  LibraryFile({
    this.id,
    this.title = '',
    this.category = 'أخرى',
    this.note = '',
    this.ref = '',
    this.principle = '',
    required this.file,
    this.ext = '',
    this.size = 0,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;
  factory LibraryFile.fromMap(Map<String, Object?> m) => LibraryFile(
        id: _n(m['id']),
        title: _s(m['title']),
        category: _s(m['category']),
        note: _s(m['note']),
        ref: _s(m['ref']),
        principle: _s(m['principle']),
        file: _s(m['file']),
        ext: _s(m['ext']),
        size: _n(m['size']) ?? 0,
        createdAt: _n(m['created_at']),
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'note': note,
        'ref': ref,
        'principle': principle,
        'file': file,
        'ext': ext,
        'size': size,
        'created_at': createdAt,
      };
}

/// التزام شخصي/عائلي: دَين لي أو عليّ، إيجار، قسط، فاتورة، مصروف دوري...
class Obligation {
  int? id;
  String kind; // مفتاح من obligationKinds
  String title, party, phone, notes;
  double amount, paid;
  DateTime? due;
  String repeat; // none | monthly | yearly
  String status; // open | done
  DateTime? remindAt;
  int createdAt;
  Obligation({
    this.id,
    this.kind = 'owed_by_me',
    this.title = '',
    this.party = '',
    this.phone = '',
    this.notes = '',
    this.amount = 0,
    this.paid = 0,
    this.due,
    this.repeat = 'none',
    this.status = 'open',
    this.remindAt,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  double get remaining => (amount - paid) < 0 ? 0 : amount - paid;
  bool get done => status == 'done';
  bool get incoming => obligationKinds[kind]?.incoming ?? false;
  bool get overdue => !done && due != null && dayStart(due!).isBefore(dayStart(DateTime.now()));

  factory Obligation.fromMap(Map<String, Object?> m) => Obligation(
        id: _n(m['id']),
        kind: _s(m['kind']).isEmpty ? 'other' : _s(m['kind']),
        title: _s(m['title']),
        party: _s(m['party']),
        phone: _s(m['phone']),
        notes: _s(m['notes']),
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        paid: (m['paid'] as num?)?.toDouble() ?? 0,
        due: _n(m['due']) == null ? null : DateTime.fromMillisecondsSinceEpoch(_n(m['due'])!),
        repeat: _s(m['repeat']).isEmpty ? 'none' : _s(m['repeat']),
        status: _s(m['status']).isEmpty ? 'open' : _s(m['status']),
        remindAt: _n(m['remind_at']) == null ? null : DateTime.fromMillisecondsSinceEpoch(_n(m['remind_at'])!),
        createdAt: _n(m['created_at']),
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'kind': kind,
        'title': title,
        'party': party,
        'phone': phone,
        'notes': notes,
        'amount': amount,
        'paid': paid,
        'due': due?.millisecondsSinceEpoch,
        'repeat': repeat,
        'status': status,
        'remind_at': remindAt?.millisecondsSinceEpoch,
        'created_at': createdAt,
      };
}

class ObligationPayment {
  int? id;
  int obligationId;
  double amount;
  DateTime date;
  String note;
  ObligationPayment({this.id, required this.obligationId, this.amount = 0, required this.date, this.note = ''});
  factory ObligationPayment.fromMap(Map<String, Object?> m) => ObligationPayment(
        id: _n(m['id']),
        obligationId: _n(m['obligation_id'])!,
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        date: DateTime.fromMillisecondsSinceEpoch(_n(m['date'])!),
        note: _s(m['note']),
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'obligation_id': obligationId,
        'amount': amount,
        'date': date.millisecondsSinceEpoch,
        'note': note,
      };
}
