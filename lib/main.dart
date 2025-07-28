import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'dart:html' as html;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
  final dbRef = FirebaseDatabase.instance.ref("state");
  final player = AudioPlayer();
  StreamSubscription<DatabaseEvent>? _subscription;
  dynamic previousValue;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    debugPrint("👂 리스너 시작됨");
    _subscription = dbRef.onValue.listen((event) async {
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
      if (kIsWeb) {
        final audio = html.AudioElement()
          ..src = "assets/audio.mp3"
          ..autoplay = true;
        html.document.body?.append(audio);
      } else {
        await player.play(AssetSource("assets/audio.mp3"));
      }
    } catch (e) {
      debugPrint("❌ 소리 재생 실패: $e");
    }
  }

  void _sendAlert() async {
    final snapshot = await dbRef.get();
    final current = snapshot.value as int? ?? 0;
    final next = current == 1 ? 0 : 1;

    await dbRef.set(next);
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
                const Text(
                  "🔊 Firebase 값 변경 시 자동 경고음 발생",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                if (widget.isAdmin) ...[
                  const SizedBox(height: 20),
                  const Text("👮 관리자 모드입니다."),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _sendAlert,
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
    return WillPopScope(
      onWillPop: () async => false,
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