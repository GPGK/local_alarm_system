import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();



  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }
  // 앱 아이콘의 Badge를 초기화하는 코드를 기본적으로 제공하지 않는다.
  // 따라서 FlutterAppBader을 사용하여 '앱이 Foreground 상태가 될때 뱃지를 초기화할 필요가 있다.'

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FlutterAppBadger.removeBadge();
    }
  }

  Future<void> _init() async {
    await _configureLocalTimeZone();
    await _initializeNotification();
  }
  // flutter_local_notification 초기화
  // ..를 사용하여 특정 시간에 로컬 푸시 메시지를 표시하기 위해서는 '초기화가 필요하다.'

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    final String? timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName!));
  } // 위 코드를 사용하여 [현재 단말기의 현재 시간을 등록]합니다.


  // 또한, 다음과 같이 [iOS의 메시지 권한 요청을 초기화]합니다.
  // iOS의 초기화시, 권한 요청 메시지가 바로 표시되지 않도록 하기 위해 모든 값을 false로 설정하였습니다.
  //
  // Android는 ic_notification을 사용하여 [푸시 메시지의 아이콘을 설정]하였습니다.
  // 해당 아이콘은 ./android/app/src/main/res/drawable* 폴더에 저장합니다.
  Future<void> _initializeNotification() async {
    // ios
    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    // Android
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('ic_notification');   // ic_notification은 drawable의 이미지 파일(알람 아이콘)
    // ios & Android
    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // [메시지 등록 취소]
  // 새로운 메시지를 등록할 때, 이전에 등록된 메시지를 모두 취소하기 위해 'cancelAll'함수를 사용하였습니다. 
  Future<void> _cancelNotification() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  // [권한 요청]
  // 푸시 메시지를 등록하기 전에, ios의 푸시 메시지 권한을 요청하도록 하였습니다.
  // 이 코드는 사용자가 권한 요청 화면에서 권한을 결정하면, 다시 사용자의 권한을 요청하지 않습니다.
  Future<void> _requestPermissions() async {
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // [메시지 등록]
  // 마지막으로, 현재 시간에서 (1분후)에 메시지가 표시될 수 있도록 푸시 메시지를 등록하였습니다.
  // 이 메시지는 (매일 동일한 시간에 메시지가 표시)됩니다.
  Future<void> _registerMessage({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minutes,
    required message,
  }) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      year,
      month,
      day,
      hour,
      minutes,
    );
    // zonedSchedule의 ID를 동일하게 설정하면,
    // 동일한 메시지가 현재 표시중이면, 메시지를 중복하여 표시하지 않습니다.
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      0,                                  // 알람 ID
      'flutter_local_notifications',      // ☆ 메시지 타이틀
      message,                            // 메시지 내용
      scheduledDate,
      NotificationDetails(
        // AndroidNotificationDetails의 ongoing을 true로 설정하면,
        // 앱을 실행해야만 메시지가 사라지도록 설정할 수 있습니다.
        android: AndroidNotificationDetails(
          'channel id',
          'channel name',
          importance: Importance.max,
          priority: Priority.high,
          ongoing: true,
          styleInformation: BigTextStyleInformation(message),
          icon: 'ic_notification',
        ),
        iOS: const DarwinNotificationDetails(
          badgeNumber: 1,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      //matchDateTimeComponents: DateTimeComponents.time,    -> 주기적으로 알림을 띄움
    );
  }

  @override
  Widget build(BuildContext context) {
    // ☆ 사용자 알람 시간 지정
    DateTime dateTime = DateTime.parse('2022-11-26 00:30:00');  // DateTime을 여기에 연결
    // 년, 월, 일, 시, 분
    int timeYear =  int.parse(dateTime.year.toString());
    int timeMonth =  int.parse(dateTime.month.toString());
    int timeDay =  int.parse(dateTime.day.toString());
    int timeHour =  int.parse(dateTime.hour.toString());
    int timeMin =  int.parse(dateTime.minute.toString());

    int termTime = 10;    // 사용자 지정 값 (몇 분 전에 알림 받기)

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Notifications'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await _cancelNotification();    // [메시지 등록 취소]
            await _requestPermissions();    // [권한 요청]

            final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
            await _registerMessage(         // [메시지 등록]
              // 각 index에 맞게  값을 입력받음
              year: timeYear,
              month: timeMonth,
              day: timeDay,
              hour: timeHour,
              minutes: timeMin - termTime,
              message: 'Hello, world!',   // ☆ 알람 메시지 내용
            );
          },
          child: const Text('Show Notification'),
        ),
      ),
    );
  }
}
// ========== 최종적으로 [앱 사용중], [앱 뒤로가기로 끌때], [백그라운드까지 완전제거]에서도 알림기능 확인됨 ====
// ========== 필요시 테스트 더 해볼 것 ====== (우선 Android에서는 정상 작동)




// 버튼 클릭시 > 권한 설정 화면 표시 > Allow를 선택한 후, 메시지를 수신할 수 있도록 설정합니다.
// 그리고 앱을 Background로 전환한 후, 1분만 기다리면 메시지가 표시되는 것을 확인할 수 있습니다.
// 그리고 앱을 실행한 후, 다시 앱 아이콘을 확인하면 다음과 같이 뱃지가 잘 사라진 것을 확인할 수 있습니다.

// [Flutter에서 flutter_local_notifications을 사용하여 로컬에서 특정 시간에 정기적으로 메시지를 발송하는 방법]

// + .. 이전 등록한 메시지를 모두 지우는 이유: 특정시간 푸시는 관계없지만, 일정주기로 보내는 경우엔 중복되서 발송될 수 있습니다.
// -- 특정시간에 푸시 메시지를 보낼 때도, id를 잘못 설정할 경우, 여러번 발송되는 경우가 있습니다.

// + .. 만약 기존 알람 시간을 변경하고 싶다면?
// .. flutter_local_notification은 수정기능을 제공하지 않으므로, 기존것을 제거하고, 새로운 시간을 재지정해야합니다.

// + '매일 오전 9시'에 알림을 등록 해 놓은 상태에서 새로 '매일 오전 11시'에 알림을 또 등록하려고 할 때 두 notification의 id를 다르게 해주면 중복 문제를 피할 수 있다고 해주셨는데 id 값을 어떻게 관리하시나요? (중복되지 않게 하기 위해 id 파라매터에 변수를 넣어놓고 새로운 알림이 등록될 때마다 변수값을 달리해서 등록해줘야할텐데 어떠한 방식으로 id 값을 관리하시는지 궁금합니다)
//
// id를 관리하기 위해서는 많은 방법이 있을거 같습니다. 예를 들어 SharedPreferences라던지, sqflite라던지, 해당 키를 저장하여 관리하시면 될거 같습니다. 시간별로 하나의 메시지만 존재한다면 단순히 시간을 id로 사용해도 될거 같습니다.