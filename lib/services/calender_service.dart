/// Provides functions to request calendar permissions and retrieve
/// today's events from the user's device calendar. Used to integrate
/// health or scheduling features into the app.

import 'package:device_calendar/device_calendar.dart';
import '../models/health_models.dart';

class CalendarService {
  /// DeviceCalendarPlugin instance used to interact with the device calendar
  static final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  /// Request permission to access the user's calendar
  /// Returns true if permission is granted, false otherwise
  static Future<bool> requestCalendarPermission() async {
    try {
      /// First check if permission is already granted
      final hasPermissionResult = await _deviceCalendarPlugin.hasPermissions();
      if (hasPermissionResult.isSuccess && (hasPermissionResult.data ?? false)) {
        return true;
      }

      /// Otherwise request permission from the user
      final requestPermissionResult = await _deviceCalendarPlugin.requestPermissions();
      return requestPermissionResult.isSuccess && (requestPermissionResult.data ?? false);
    } catch (e) {
      print('Error requesting calendar permission: $e');
      return false;
    }
  }

  /// Fetch all events happening today across all available calendars
  /// Returns a list of CalendarEvent (custom health model)
  static Future<List<CalendarEvent>> getTodayEvents() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      /// Retrieve all calendars from the device
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (!calendarsResult.isSuccess || (calendarsResult.data?.isEmpty ?? true)) {
        return [];
      }

      List<CalendarEvent> todayEvents = [];

      for (var calendar in calendarsResult.data ?? []) {
        /// Retrieve the events between today and tomorrow
        final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
          calendar.id,
          RetrieveEventsParams(
            startDate: today,
            endDate: tomorrow,
          ),
        );

        if (eventsResult.isSuccess && eventsResult.data != null) {
          for (var event in eventsResult.data!) {
            if (event.start != null && event.end != null) {
              todayEvents.add(CalendarEvent(
                id: event.eventId ?? '',
                title: event.title ?? 'Untitled Event',
                startTime: event.start!,
                endTime: event.end!,
                description: event.description,
              ));
            }
          }
        }
      }

      /// Sort events by start time in ascending order
      todayEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
      return todayEvents;
    } catch (e) {
      print('Error fetching calendar events: $e');
      return [];
    }
  }
}
