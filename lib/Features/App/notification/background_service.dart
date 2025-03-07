import 'package:workmanager/workmanager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'dart:convert';

const String TRACKING_TASK = "tracking_task";
const String MISSED_PICKUPS_TASK = "checkMissedPickups";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case MISSED_PICKUPS_TASK:
        await checkForMissedPickups();
        break;
      case TRACKING_TASK:
        await performBackgroundTracking(
          inputData!['pickupId'] as String,
          inputData['collectionName'] as String,
        );
        break;
    }
    return Future.value(true);
  });
}

Future<void> performBackgroundTracking(
    String pickupId, String collectionName) async {
  try {
    final pickupDoc = await FirebaseFirestore.instance
        .collection(collectionName)
        .doc(pickupId)
        .get();

    if (!pickupDoc.exists) return;

    final data = pickupDoc.data()!;
    if (data['status'] == 'cancelled' || data['status'] == 'completed') return;

    final position = await Geolocator.getCurrentPosition();
    final isComplete = await checkPickupCompletion(position, data);

    if (isComplete) {
      await pickupDoc.reference.update({'status': 'completed'});
      await showBackgroundNotification(
          'Pickup Complete!', 'Your waste has been successfully collected.');
      await scheduleNextPickupNotification(data['pickup_time']);
    }

    // Save tracking data for UI updates
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'last_tracking_update',
        json.encode({
          'timestamp': DateTime.now().toIso8601String(),
          'pickup_id': pickupId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'is_complete': isComplete,
        }));
  } catch (e) {
    print('Background tracking error: $e');
  }
}

Future<bool> checkPickupCompletion(
    Position position, Map<String, dynamic> data) async {
  if (data['pickup_location'] == null) return false;

  final pickupLat = data['pickup_location']['latitude'] as double;
  final pickupLng = data['pickup_location']['longitude'] as double;

  final distance = Geolocator.distanceBetween(
    position.latitude,
    position.longitude,
    pickupLat,
    pickupLng,
  );

  return distance <= 50; // Consider pickup complete if within 50 meters
}

Future<void> showBackgroundNotification(String title, String body) async {
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: DateTime.now().millisecond,
      channelKey: 'pickup_tracking',
      title: title,
      body: body,
      notificationLayout: NotificationLayout.Default,
    ),
  );
}

Future<void> scheduleNextPickupNotification(String pickupTime) async {
  final nextPickupDate = DateTime.now().add(Duration(days: 1));
  final timeFormat = DateFormat('h:mm a');
  final nextPickupDateTime = DateTime(
    nextPickupDate.year,
    nextPickupDate.month,
    nextPickupDate.day,
    timeFormat.parse(pickupTime).hour,
    timeFormat.parse(pickupTime).minute,
  );

  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: DateTime.now().millisecond,
      channelKey: 'pickup_tracking',
      title: 'Next Pickup Scheduled',
      body:
      'Your next pickup is scheduled for ${DateFormat('MMM dd, yyyy h:mm a').format(nextPickupDateTime)}',
    ),
    schedule: NotificationCalendar.fromDate(
      date: nextPickupDateTime.subtract(Duration(hours: 1)),
    ),
  );
}

Future<void> checkForMissedPickups() async {
  try {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Get all active subscriptions
    final subscriptions = await FirebaseFirestore.instance
        .collection('subscription_details')
        .where('status', isEqualTo: 'active')
        .get();

    for (var subscription in subscriptions.docs) {
      final data = subscription.data();
      final pickupTime = data['pickup_time'] as String;

      if (!await isPickupConfirmed(subscription.id) &&
          isPickupWindowExpired(pickupTime)) {
        await addToMissedPickups(subscription.id, data);
      }
    }

    // Check special day pickups
    final specialDayPickups = await FirebaseFirestore.instance
        .collection('special_day_details')
        .where('status', isEqualTo: 'active')
        .where('pickup_date', isEqualTo: Timestamp.fromDate(today))
        .get();

    for (var pickup in specialDayPickups.docs) {
      final data = pickup.data();
      final pickupTime = data['pickup_time'] as String;

      if (!await isPickupConfirmed(pickup.id) &&
          isPickupWindowExpired(pickupTime)) {
        await addToMissedPickups(pickup.id, data, isSpecialDay: true);
      }
    }
  } catch (e) {
    print('Error checking missed pickups: $e');
  }
}

bool isPickupWindowExpired(String pickupTime) {
  try {
    final format = DateFormat("hh:mm a");
    final now = DateTime.now();
    final pickupDateTime = format.parse(pickupTime);

    final scheduledPickup = DateTime(
      now.year,
      now.month,
      now.day,
      pickupDateTime.hour,
      pickupDateTime.minute,
    );

    final pickupWindowEnd = scheduledPickup.add(Duration(minutes: 30));
    return now.isAfter(pickupWindowEnd);
  } catch (e) {
    print('Error parsing pickup time: $e');
    return false;
  }
}

Future<bool> isPickupConfirmed(String id) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final confirmedJson = prefs.getString('confirmed_pickups') ?? '{}';
    final Map<String, dynamic> confirmedPickups = json.decode(confirmedJson);
    return confirmedPickups[id] ?? false;
  } catch (e) {
    print('Error checking pickup confirmation: $e');
    return false;
  }
}

Future<void> addToMissedPickups(String id, Map<String, dynamic> data,
    {bool isSpecialDay = false}) async {
  try {
    await FirebaseFirestore.instance.collection('missed_pickups').add({
      'subscription_id': isSpecialDay ? null : id,
      'special_day_id': isSpecialDay ? id : null,
      'customer_id': data['customer_id'],
      'scheduled_date': DateTime.now(),
      'scheduled_time': data['pickup_time'],
      'subscription_type':
      isSpecialDay ? 'special_day' : data['subscription_type'],
      'missed_at': DateTime.now(),
      'status': 'missed'
    });

    // If it's a special day pickup, update its status to missed
    if (isSpecialDay) {
      await FirebaseFirestore.instance
          .collection('special_day_details')
          .doc(id)
          .update({'status': 'missed'});
    }
  } catch (e) {
    print('Error adding to missed pickups: $e');
  }
}

class BackgroundService {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);

    // Schedule periodic task to check for missed pickups
    await Workmanager().registerPeriodicTask(
      MISSED_PICKUPS_TASK,
      MISSED_PICKUPS_TASK,
      frequency: Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  static Future<void> startTrackingTask(
      String pickupId, String collectionName) async {
    await Workmanager().registerPeriodicTask(
      '${TRACKING_TASK}_$pickupId',
      TRACKING_TASK,
      frequency: Duration(minutes: 15),
      inputData: {
        'pickupId': pickupId,
        'collectionName': collectionName,
      },
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  }

  static Future<void> stopTrackingTask(String pickupId) async {
    await Workmanager().cancelByUniqueName('${TRACKING_TASK}_$pickupId');
  }
}
