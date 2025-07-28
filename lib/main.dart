import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 웹 플랫폼에서만 Firebase 초기화
  if (kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("✅ Firebase 초기화 성공 (웹)");
    } catch (e) {
      debugPrint("❌ Firebase 초기화 실패: $e");
    }
  } else {
    debugPrint("⚠️ 현재 웹 플랫폼에서만 Firebase를 지원합니다.");
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const AlarmHome(),
    );
  }
}

class AlarmHome extends StatefulWidget {
  final bool isAdmin;
  const AlarmHome({super.key, this.isAdmin = false});
  @override
  State<AlarmHome> createState() => _AlarmHomeState();
}

class _AlarmHomeState extends State<AlarmHome> {
  DatabaseReference? dbRef;
  final player = AudioPlayer();
  StreamSubscription<DatabaseEvent>? _subscription;
  dynamic previousValue;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  void _initializeFirebase() {
    if (kIsWeb) {
      try {
        dbRef = FirebaseDatabase.instance.ref("state");
        _startListening();
      } catch (e) {
        debugPrint("❌ Firebase Database 초기화 실패: $e");
      }
    } else {
      debugPrint("⚠️ 웹 플랫폼에서만 Firebase Database를 사용할 수 있습니다.");
    }
  }

  void _startListening() {
    if (dbRef == null) {
      debugPrint("❌ Firebase Database가 초기화되지 않았습니다.");
      return;
    }
    
    debugPrint("👂 리스너 시작됨");
    _subscription = dbRef!.onValue.listen((event) async {
      final currentValue = event.snapshot.value;
      debugPrint("📡 Firebase 값 감지: $currentValue");

      if (currentValue != previousValue) {
        if (previousValue != null && !widget.isAdmin) {
          debugPrint("🔔 값 변경 감지: $previousValue → $currentValue");
          await _playSound();
        }
        previousValue = currentValue;
      }
    });
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _playSound() async {
    try {
      // AudioPlayer가 웹과 모바일 모두 지원하므로 통일된 방식 사용
      await player.play(AssetSource("audio.mp3"));
      debugPrint("🔊 소리 재생 성공");
    } catch (e) {
      debugPrint("❌ 소리 재생 실패: $e");
    }
  }

  void _sendAlert() async {
    if (dbRef == null) {
      debugPrint("❌ Firebase Database가 초기화되지 않았습니다.");
      _showErrorDialog("Firebase가 초기화되지 않았습니다.");
      return;
    }

    try {
      final snapshot = await dbRef!.get();
      final current = snapshot.value as int? ?? 0;
      final next = current == 1 ? 0 : 1;

      await dbRef!.set(next);
      debugPrint("📤 관리자에 의해 값 변경: $current → $next");

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("📣 알림"),
          content: const Text("알림을 보냈습니다."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("확인"),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint("❌ 알림 전송 실패: $e");
      _showErrorDialog("알림 전송에 실패했습니다: $e");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("❌ 오류"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  void _goToAdminLoginPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginPage()),
    );
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📡 실시간 알림 시스템"),
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Firebase 연결 상태 표시
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: dbRef != null ? Colors.green.shade50 : Colors.red.shade50,
                    border: Border.all(
                      color: dbRef != null ? Colors.green : Colors.red,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        dbRef != null ? Icons.check_circle : Icons.error,
                        color: dbRef != null ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dbRef != null ? "Firebase 연결됨" : "Firebase 연결 안됨",
                        style: TextStyle(
                          color: dbRef != null ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "🔊 Firebase 값 변경 시 자동 경고음 발생",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                if (!kIsWeb) ...[
                  const SizedBox(height: 16),
                  const Text(
                    "⚠️ 현재 웹 브라우저에서만 Firebase를 지원합니다.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.orange),
                  ),
                ],
                if (widget.isAdmin) ...[
                  const SizedBox(height: 20),
                  const Text("👮 관리자 모드입니다."),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: dbRef != null ? _sendAlert : null,
                    child: const Text("🔃 상태 변경 (알림 보내기)"),
                  ),
                ]
              ],
            ),
          ),
          if (!widget.isAdmin)
            Positioned(
              top: 16,
              right: 16,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text("관리자"),
                onPressed: _goToAdminLoginPage,
              ),
            ),
        ],
      ),
    );
  }
}

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  String? _error;

  void _login() {
    final id = _idController.text.trim();
    final pw = _pwController.text.trim();
    if (id == "admin" && pw == "1234") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AlarmHome(isAdmin: true)),
      );
    } else {
      setState(() {
        _error = "❌ 로그인 실패: ID 또는 비밀번호가 잘못되었습니다.";
      });
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: const Text("👮 관리자 로그인")),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              TextField(
                controller: _idController,
                decoration: const InputDecoration(labelText: "ID"),
                onSubmitted: (_) => _login(),
              ),
              TextField(
                controller: _pwController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password"),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _login,
                child: const Text("로그인"),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}