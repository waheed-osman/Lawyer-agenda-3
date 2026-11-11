import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils.dart';
import '../data/db.dart';
import '../data/models.dart';

/// Local (offline) reminders: the evening before (18:00) and the morning of
/// the session day (07:30).
class Notifier {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// قناة جديدة (v2) بصوت صريح واهتزاز واستخدام "منبّه"، فيُسمَع التنبيه حتى لو صوت الإشعارات منخفض.
  /// (إعدادات القناة لا تتغير بعد إنشائها، لذلك اسم جديد.)
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'agenda_alarm_v2',
      'تنبيهات الجلسات والمواعيد',
      channelDescription: 'تذكير صوتي بالجلسات والمواعيد والمواعيد القانونية',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
    ),
  );

  static const defaultEveningMin = 18 * 60;
  static const defaultMorningMin = 7 * 60 + 30;
  static const _kEve = 'rem_eve_min';
  static const _kMorn = 'rem_morn_min';

  /// أوقات التنبيه الافتراضية (دقائق من منتصف الليل): مساء اليوم السابق، وصباح يوم الجلسة.
  static Future<(int, int)> defaultTimes() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return (sp.getInt(_kEve) ?? defaultEveningMin, sp.getInt(_kMorn) ?? defaultMorningMin);
    } catch (_) {
      return (defaultEveningMin, defaultMorningMin);
    }
  }

  static Future<void> saveDefaultTimes(int eve, int morn) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(_kEve, eve);
      await sp.setInt(_kMorn, morn);
    } catch (_) {}
  }

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    }
    const init = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _plugin.initialize(init);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    try {
      // أندرويد 12+: التنبيه في الدقيقة المحددة يحتاج إذن "المنبهات والتذكيرات"
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  static String _body(CaseSession s) {
    final parts = <String>[
      sessionTypes[s.type] ?? '',
      caseLabel(s.caseNumber, s.caseYear),
      if (s.clientName.isNotEmpty) s.clientName,
      if (s.court.isNotEmpty) s.court,
      if (s.roll.isNotEmpty) 'رول ${s.roll}',
    ];
    return parts.where((e) => e.isNotEmpty).join(' - ');
  }

  static Future<void> _at(int id, DateTime when, String title, String body,
      {NotificationDetails details = _details}) async {
    final t = tz.TZDateTime(tz.local, when.year, when.month, when.day, when.hour, when.minute);
    if (!t.isAfter(tz.TZDateTime.now(tz.local))) return;
    Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          title,
          body,
          t,
          details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
    try {
      await go(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      // لا يوجد إذن المنبّهات الدقيقة: نرجع للجدولة التقريبية بدل ضياع التنبيه
      await go(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// Cancels everything and schedules reminders for all upcoming sessions.
  static Future<void> rescheduleAll() async {
    try {
      await _plugin.cancelAll();
      final list = await Db.i.sessions(from: dayStart(DateTime.now()), limit: 120);
      final (eve, morn) = await defaultTimes();
      for (final s in list) {
        final d = dayStart(s.date);
        final body = _body(s);
        if (s.remindAt != null) {
          // تنبيه مخصص بدل الافتراضيين
          await _at(s.id! * 10 + 3, s.remindAt!, 'تذكير: جلسة ${fmtShort(s.date)}', body);
        } else {
          await _at(s.id! * 10 + 1, DateTime(d.year, d.month, d.day - 1, 0, eve), 'تذكير: جلسة غدًا', body);
          await _at(s.id! * 10 + 2, DateTime(d.year, d.month, d.day, 0, morn), 'جلسة اليوم', body);
        }
      }
      // المواعيد العامة: تذكير قبلها بيوم 6 مساءً، وقبلها بساعة (أو 8 صباحًا لو بدون وقت).
      final appts = await Db.i.appointments(from: dayStart(DateTime.now()));
      for (final a in appts.take(120)) {
        final d = dayStart(a.date);
        final base = 500000000 + a.id! * 10;
        if (a.remindAt != null) {
          await _at(base + 5, a.remindAt!, 'تذكير: ${apptKind(a.kind).label}', a.title);
        } else {
          await _at(base + 1, DateTime(d.year, d.month, d.day - 1, 0, eve), 'تذكير: موعد غدًا', a.title);
          final dayOf = a.minutes == null
              ? DateTime(d.year, d.month, d.day, 8, 0)
              : DateTime(d.year, d.month, d.day, 0, a.minutes! - 60);
          await _at(base + 2, dayOf, a.minutes == null ? 'موعد اليوم' : 'موعد بعد ساعة', a.title);
        }
        // الميعاد القانوني (شهادة/معارضة/استئناف/نقض): تنبيه مبكر قبله بـ7 أيام و3 أيام الساعة 9 صباحًا.
        if (apptKind(a.kind).legal) {
          final k = apptKind(a.kind).label;
          await _at(base + 3, DateTime(d.year, d.month, d.day - 7, 9, 0), 'ميعاد $k بعد 7 أيام', a.title);
          await _at(base + 4, DateTime(d.year, d.month, d.day - 3, 9, 0), 'ميعاد $k بعد 3 أيام', a.title);
        }
      }
      // انتهاء التوكيل: تنبيه قبله بـ30 يومًا وبـ7 أيام الساعة 9 صباحًا.
      for (final c in await Db.i.cases(archived: false)) {
        final e = c.poaExpiry;
        if (e == null || e.isBefore(dayStart(DateTime.now()))) continue;
        final base = 900000000 + c.id! * 10;
        final what = 'توكيل ${c.poaNo.isEmpty ? '' : 'رقم ${c.poaNo} '}- ${caseLabel(c.number, c.year)}';
        await _at(base + 1, DateTime(e.year, e.month, e.day - 30, 9, 0), 'ينتهي التوكيل بعد 30 يومًا', what);
        await _at(base + 2, DateTime(e.year, e.month, e.day - 7, 9, 0), 'ينتهي التوكيل بعد 7 أيام', what);
      }
      // الالتزامات الشخصية المفتوحة: مساء اليوم السابق + صباح يوم الاستحقاق (أو تنبيه مخصص).
      final obls = await Db.i.obligations(done: false);
      final today = dayStart(DateTime.now());
      for (final o in obls.where((o) => o.due != null && !dayStart(o.due!).isBefore(today)).take(120)) {
        final d = dayStart(o.due!);
        final base = 700000000 + o.id! * 10;
        final k = obligationKind(o.kind);
        final who = o.party.isEmpty ? o.title : '${o.title} - ${o.party}';
        final body = '$who • المتبقي ${fmtMoney(o.remaining)}';
        if (o.remindAt != null) {
          await _at(base + 5, o.remindAt!, 'تذكير: ${k.label}', body);
        } else {
          await _at(base + 1, DateTime(d.year, d.month, d.day - 1, 0, eve),
              o.incoming ? 'غدًا موعد استحقاق مبلغ لك' : 'غدًا موعد التزام', body);
          await _at(base + 2, DateTime(d.year, d.month, d.day, 0, morn),
              o.incoming ? 'اليوم موعد استحقاق مبلغ لك' : 'اليوم موعد التزام', body);
        }
      }
    } catch (_) {}
  }

  static Future<void> testNow() => _plugin.show(
        999999999,
        'تنبيه تجريبي',
        'التنبيهات تعمل بشكل سليم ✔',
        _details,
      );
}
