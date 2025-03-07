import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({Key? key}) : super(key: key);

  @override
  _NotificationPreferencesPageState createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  bool _pickupReminders = true;
  bool _orderUpdates = true;
  bool _promotionalNotifications = false;
  bool _newsAndTips = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pickupReminders = prefs.getBool('pickup_reminders') ?? true;
      _orderUpdates = prefs.getBool('order_updates') ?? true;
      _promotionalNotifications =
          prefs.getBool('promotional_notifications') ?? false;
      _newsAndTips = prefs.getBool('news_and_tips') ?? true;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pickup_reminders', _pickupReminders);
    await prefs.setBool('order_updates', _orderUpdates);
    await prefs.setBool('promotional_notifications', _promotionalNotifications);
    await prefs.setBool('news_and_tips', _newsAndTips);
  }

  Widget _buildNotificationOption({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.green.shade800),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: (newValue) {
            setState(() {
              onChanged(newValue);
              _savePreferences();
            });
          },
          activeColor: Colors.green.shade800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Notification Preferences',
          style: GoogleFonts.poppins(
            color: Colors.green.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.green.shade800),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Manage your notification preferences',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            _buildNotificationOption(
              title: 'Pickup Reminders',
              subtitle: 'Get reminded about your scheduled pickups',
              value: _pickupReminders,
              onChanged: (value) => _pickupReminders = value,
              icon: Icons.access_time,
            ),
            _buildNotificationOption(
              title: 'Order Updates',
              subtitle: 'Stay informed about your order status',
              value: _orderUpdates,
              onChanged: (value) => _orderUpdates = value,
              icon: Icons.local_shipping,
            ),
            _buildNotificationOption(
              title: 'Promotional Notifications',
              subtitle: 'Receive special offers and promotions',
              value: _promotionalNotifications,
              onChanged: (value) => _promotionalNotifications = value,
              icon: Icons.local_offer,
            ),
            _buildNotificationOption(
              title: 'News & Tips',
              subtitle: 'Get updates about waste management tips',
              value: _newsAndTips,
              onChanged: (value) => _newsAndTips = value,
              icon: Icons.tips_and_updates,
            ),
          ].animate(interval: 100.ms).fadeIn().slideX(),
        ),
      ),
    );
  }
}
