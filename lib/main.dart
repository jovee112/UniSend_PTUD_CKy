import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_fonts/google_fonts.dart';
import 'views/auth/login_screen.dart';
import 'views/auth/register_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase: trên web cần truyền FirebaseOptions
  if (kIsWeb) {
    // Cấu hình Web App từ Firebase Console (đã cung cấp)
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyCLlnY29C7EVjOw-eW5hziZ0N-y_vkZjv8',
        authDomain: 'unisend-n4-ptud-ck.firebaseapp.com',
        projectId: 'unisend-n4-ptud-ck',
        storageBucket: 'unisend-n4-ptud-ck.firebasestorage.app',
        messagingSenderId: '1088634361868',
        appId: '1:1088634361868:web:dfca21a76007d87f13b629',
        measurementId: 'G-VZM64B75R2',
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  await Supabase.initialize(
    url: 'https://tsnitkxrditmobzhjzme.supabase.co',
    anonKey: 'sb_publishable_A4YYuzcJqwGuo1CQkX8AMA_CkuikmKM',
  );

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _auth = fb.FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ),
      routes: {
        '/login': (c) => LoginScreen(onSignedIn: () => setState(() {})),
        '/register': (c) => const RegisterScreen(),
      },
      home: StreamBuilder<fb.User?>(
        stream: _auth.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return Scaffold(
              appBar: AppBar(title: const Text('UniSend')),
              body:
                  Center(child: Text('Đã đăng nhập: ${snapshot.data!.email}')),
            );
          }
          return LoginScreen(onSignedIn: () => setState(() {}));
        },
      ),
    );
  }
}
