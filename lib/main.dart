import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutternew/Features/App/notification/background_service.dart';
import 'package:flutternew/Features/App/splash_screen/welcome.dart';
import 'package:provider/provider.dart';
import 'Features/App/home/home.dart';
import 'Features/App/market/OGprovidere.dart';
import 'Features/App/splash_screen/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
    if (!isAllowed) {
      AwesomeNotifications().requestPermissionToSendNotifications();
    }
  });
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyBoEfynFgftXEWeTKigDaWS0FK1Zczk1rY",
      appId: "1:935307424826:android:6ba63ec26bea64438e3103",
      messagingSenderId: "935307424826",
      projectId: "wastewisepro",
    ),
  );
  await BackgroundService.initialize();
  AwesomeNotifications().initialize(
    'resource://drawable/res_notification_app_icon',
    [
      NotificationChannel(
        channelKey: 'pickup_channel',
        channelName: 'Pickup Notifications',
        channelDescription: 'Notifications for upcoming pickups',
        defaultColor: Color(0xFF2E7D32),
        ledColor: Colors.white,
        importance: NotificationImportance.High,
      )
    ],
  );

  runApp(
    ChangeNotifierProvider(
      create: (context) => CartProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  FirebaseAuth auth = FirebaseAuth.instance;
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      builder: (context, child) => MaterialApp(
        title: 'WasteWisePro',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.green),
        home: auth.currentUser != null
            ? const SplashScreen(child: home())
            : SplashScreen(child: welcome()),
        //OrderTrackingPage()
      ),
      designSize: const Size(360, 690),
      splitScreenMode: true,
      minTextAdapt: true,
    );
  }
}
