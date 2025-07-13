import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutternew/Features/App/User_auth/util/screen_util.dart';
import 'package:flutternew/Features/App/splash_screen/welcome.dart';
import 'package:provider/provider.dart';
import 'Features/App/home/home.dart';
import 'Features/App/market/OGprovidere.dart';
import 'Features/App/splash_screen/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
    if (!isAllowed) {
      AwesomeNotifications().requestPermissionToSendNotifications();
    }
  });

  // Initialize Firebase
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyBoEfynFgftXEWeTKigDaWS0FK1Zczk1rY",
      appId: "1:935307424826:android:6ba63ec26bea64438e3103",
      messagingSenderId: "935307424826",
      projectId: "wastewisepro",
    ),
  );

  // Configure notification channels
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

  // Run the app with provider
  runApp(
    ChangeNotifierProvider(
      create: (context) => CartProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  final FirebaseAuth auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designWidth: 360,
      designHeight: 690,
      builder: (context, child) {
        return MaterialApp(
          title: 'WasteWisePro',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.green,
          ),
          builder: (context, widget) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
              child: widget!,
            );
          },
          home: FutureBuilder(
            future: Future.delayed(Duration.zero),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return auth.currentUser != null
                    ? const SplashScreen(child: home())
                    : SplashScreen(child: welcome());
              }
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
