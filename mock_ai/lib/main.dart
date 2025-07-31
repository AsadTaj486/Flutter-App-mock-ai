import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/interview_question_screen.dart';
import 'screens/answer_review_screen.dart';
import 'screens/facial_body_analysis_screen.dart';
import 'screens/automated_feedback_report_screen.dart';
import 'screens/history_comparison_screen.dart';
import 'screens/settings_profile_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // ✅ Initialize Firebase here
  runApp(const MockAIApp());
}

class MockAIApp extends StatelessWidget {
  const MockAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mock AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.grey.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
  '/': (context) => const SplashScreen(),
  '/auth': (context) => const AuthScreen(),
  '/upload': (context) => const UploadScreen(),
  '/review': (context) => const AnswerReviewScreen(),
  '/history': (context) => const HistoryComparisonScreen(),
  '/settings': (context) => const SettingsProfileScreen(),

  // Add this feedback route
  '/feedback': (context) {
    final result = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    return FeedbackScreen(result: result);
  },

  '/analysis': (context) {
    final result = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    return FacialBodyAnalysisScreen(result: result);
  },
},
    );
  }
}
