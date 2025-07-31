import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackScreen extends StatefulWidget {
  final Map<String, dynamic> result;

  const FeedbackScreen({Key? key, required this.result}) : super(key: key);

  @override
  _FeedbackScreenState createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  late Future<Map<String, dynamic>> feedbackFuture;
  Duration? responseTime;
  
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    feedbackFuture = generateFeedback(widget.result);
  }

  Future<Map<String, dynamic>> generateFeedback(Map<String, dynamic> result) async {
    final url = Uri.parse('http://192.168.18.47:8000/feedback/generate'); // Backend endpoint

    try {
      final stopwatch = Stopwatch()..start(); // Start timer

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'results': [result]}),
      );

      stopwatch.stop(); // Stop timer
      setState(() {
        responseTime = stopwatch.elapsed;
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data != null && data is Map<String, dynamic>) {
          // Save feedback to both SharedPreferences AND Firebase
          await _saveFeedbackToStorage(data);
          return data;
        } else {
          throw Exception("Invalid data format received.");
        }
      } else {
        throw Exception('Failed to fetch feedback. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print("Feedback fetch error: $e");
      return {
        "feedback": {
          "strengths": ["Error retrieving feedback."],
          "weaknesses": [],
          "suggestions": [],
          "confidence_score": 0
        }
      };
    }
  }

  Future<void> _saveFeedbackToStorage(Map<String, dynamic> feedbackData) async {
    final feedbackDate = DateTime.now().toIso8601String();
    
    try {
      // 1. Save to SharedPreferences (for quick access)
      final prefs = await SharedPreferences.getInstance();
      final feedbackJson = jsonEncode(feedbackData);
      await prefs.setString('latest_feedback', feedbackJson);
      await prefs.setString('feedback_date', feedbackDate);
      
      // 2. Save to Firebase Firestore (persistent across sessions)
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'latest_feedback': feedbackData,
          'feedback_date': feedbackDate,
          'updated_at': FieldValue.serverTimestamp(),
        });
        
        // Also save to feedback history collection
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('feedback_history')
            .add({
          'feedback': feedbackData,
          'interview_result': widget.result,
          'created_at': FieldValue.serverTimestamp(),
          'feedback_date': feedbackDate,
        });
        
        print('Feedback saved to Firebase successfully');
      } else {
        print('No authenticated user, feedback saved only to SharedPreferences');
      }
    } catch (e) {
      print('Error saving feedback: $e');
      // Even if Firebase fails, we still have SharedPreferences backup
    }
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(String title, List<String> items, Color color, IconData icon) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.asMap().entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade50, Colors.white],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Analyzing Your Performance...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we generate your feedback',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Method to navigate to profile
  void _navigateToProfile() {
    try {
      Navigator.pushNamedAndRemoveUntil(
        context, 
        '/settings', 
        (route) => false,
      );
    } catch (e) {
      print('Navigation error: $e');
      // Fallback navigation
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/settings',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Performance Feedback',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[600],
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: feedbackFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          } else if (snapshot.hasError) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Oops! Something went wrong',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _navigateToProfile,
                      child: const Text('Go to Profile'),
                    ),
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data == null) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.feedback_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No feedback available',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unable to retrieve feedback at this time',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _navigateToProfile,
                      child: const Text('Go to Profile'),
                    ),
                  ],
                ),
              ),
            );
          } else {
            final feedbackWrapper = snapshot.data!;
            final feedback = feedbackWrapper['feedback'] ?? {};

            final strengths = List<String>.from(feedback['strengths'] ?? []);
            final weaknesses = List<String>.from(feedback['weaknesses'] ?? []);
            final suggestions = List<String>.from(feedback['suggestions'] ?? []);
            final confidenceScore = feedback['confidence_score'] ?? 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[700]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.analytics,
                          color: Colors.white,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Analysis Complete!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Here\'s your detailed performance feedback',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // Metrics Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Confidence Score',
                          '$confidenceScore%',
                          Colors.purple,
                          Icons.trending_up,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'Response Time',
                          responseTime != null 
                              ? '${responseTime!.inMilliseconds}ms'
                              : 'N/A',
                          Colors.orange,
                          Icons.timer,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Feedback Sections
                  _buildFeedbackSection(
                    'Strengths',
                    strengths,
                    Colors.green,
                    Icons.thumb_up,
                  ),

                  _buildFeedbackSection(
                    'Areas for Improvement',
                    weaknesses,
                    Colors.orange,
                    Icons.warning_amber,
                  ),

                  _buildFeedbackSection(
                    'Recommendations',
                    suggestions,
                    Colors.blue,
                    Icons.lightbulb,
                  ),

                  const SizedBox(height: 24),

                  // Go to Profile Button (FIXED)
                  Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _navigateToProfile, // Use the fixed method
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        elevation: 4,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Go to Profile',
                            style: TextStyle(
                              fontSize: 18, 
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}