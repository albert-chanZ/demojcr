import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

enum TicketReminderResult {
  scheduled,
  notNeeded,
  tooLate,
  permissionDenied,
  unsupported,
}

class TicketReminderService {
  TicketReminderService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _timeZonesInitialized = false;

  static Future<TicketReminderResult> schedule({
    required String ticketId,
    required int folio,
    required DateTime? fechaProgramada,
    required bool completado,
  }) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS &&
            defaultTargetPlatform != TargetPlatform.windows)) {
      return TicketReminderResult.unsupported;
    }

    await _initialize();
    final notificationId = _notificationId(ticketId);
    await _notifications.cancel(id: notificationId);

    if (completado || fechaProgramada == null) {
      return TicketReminderResult.notNeeded;
    }

    final fechaRecordatorio = fechaProgramada.subtract(
      const Duration(hours: 1),
    );
    if (!fechaRecordatorio.isAfter(DateTime.now())) {
      return TicketReminderResult.tooLate;
    }

    final permisoConcedido = await _requestPermission();
    if (!permisoConcedido) {
      return TicketReminderResult.permissionDenied;
    }

    if (!_timeZonesInitialized) {
      timezone_data.initializeTimeZones();
      _timeZonesInitialized = true;
    }
    final timezone.Location zonaLocal;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      // Windows schedules by epoch time, so UTC preserves the local appointment instant.
      zonaLocal = timezone.UTC;
    } else {
      final zona = await FlutterTimezone.getLocalTimezone();
      zonaLocal = timezone.getLocation(zona.identifier);
    }

    await _notifications.zonedSchedule(
      id: notificationId,
      title: 'Recordatorio de servicio',
      body:
          'Ticket #$folio: servicio programado para '
          '${_formatDateTime(fechaProgramada)}.',
      scheduledDate: timezone.TZDateTime.from(fechaRecordatorio, zonaLocal),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'ticket_reminders',
          'Recordatorios de tickets',
          channelDescription: 'Avisos una hora antes de servicios programados',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: ticketId,
    );

    return TicketReminderResult.scheduled;
  }

  static Future<void> _initialize() async {
    if (_initialized) return;

    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        windows: WindowsInitializationSettings(
          appName: 'Sistema de Tickets - JCR',
          appUserModelId: 'com.example.demojcr',
          guid: '803b1d42-3fae-4b73-9b41-9455de20938d',
        ),
      ),
    );
    _initialized = true;
  }

  static Future<bool> _requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final granted = await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted == true;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final granted = await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true);
      return granted == true;
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      return true;
    }

    final granted = await _notifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true);
    return granted == true;
  }

  static int _notificationId(String ticketId) {
    var hash = 0;
    for (final codeUnit in ticketId.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  static String _formatDateTime(DateTime dateTime) {
    final date =
        '${dateTime.year}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')}';
    final time =
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}
