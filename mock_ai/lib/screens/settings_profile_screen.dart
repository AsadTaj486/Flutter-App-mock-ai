import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Add this import
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import

class SettingsProfileScreen extends StatefulWidget {
  const SettingsProfileScreen({super.key});

  @override
  _SettingsProfileScreenState createState() => _SettingsProfileScreenState();
}

class _SettingsProfileScreenState extends State<SettingsProfileScreen> {
  String userName = '';
  String userEmail = '';
  Map<String, dynamic>? latestFeedback;
  String? feedbackDate;
  bool isLoadingFeedback = true;
  bool isLoadingUserData = true;
  bool isDarkTheme = false;
  bool isLoggingOut = false; // Add loading state for logout

  final FirebaseAuth _auth = FirebaseAuth.instance; // Add Firebase Auth instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Add this line - MISSING FIRESTORE INSTANCE

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSavedFeedback();
    _loadThemePreference();
  }

  Future<void> _loadUserData() async {
    try {
      // First try to get data from Firebase Auth
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        setState(() {
          userName = currentUser.displayName ?? 'User';
          userEmail = currentUser.email ?? 'user@example.com';
          isLoadingUserData = false;
        });
      } else {
        // Fallback to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          userName = prefs.getString('user_name') ?? 'User';
          userEmail = prefs.getString('user_email') ?? 'user@example.com';
          isLoadingUserData = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        userName = 'User';
        userEmail = 'user@example.com';
        isLoadingUserData = false;
      });
    }
  }

  Future<void> _loadSavedFeedback() async {
    try {
      final currentUser = _auth.currentUser;
      
      // First try to load from Firebase Firestore (persistent)
      if (currentUser != null) {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          
          if (userData.containsKey('latest_feedback') && userData['latest_feedback'] != null) {
            setState(() {
              latestFeedback = userData['latest_feedback'];
              feedbackDate = userData['feedback_date'];
              isLoadingFeedback = false;
            });
            
            // Also update SharedPreferences for sync
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('latest_feedback', jsonEncode(userData['latest_feedback']));
            await prefs.setString('feedback_date', userData['feedback_date'] ?? '');
            
            print('Feedback loaded from Firebase Firestore');
            return;
          }
        }
      }
      
      // Fallback to SharedPreferences if Firebase data not available
      final prefs = await SharedPreferences.getInstance();
      final feedbackJson = prefs.getString('latest_feedback');
      final savedDate = prefs.getString('feedback_date');
      
      if (feedbackJson != null) {
        setState(() {
          latestFeedback = jsonDecode(feedbackJson);
          feedbackDate = savedDate;
          isLoadingFeedback = false;
        });
        print('Feedback loaded from SharedPreferences');
      } else {
        setState(() {
          isLoadingFeedback = false;
        });
        print('No feedback found');
      }
    } catch (e) {
      print('Error loading feedback: $e');
      setState(() {
        isLoadingFeedback = false;
      });
    }
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkTheme = prefs.getBool('dark_theme') ?? false;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_theme', value);
    setState(() {
      isDarkTheme = value;
    });
    
    // Show a snackbar to inform user about theme change
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Dark theme enabled' : 'Light theme enabled',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: value ? Colors.grey[800] : Colors.blue,
      ),
    );
  }

  Widget _buildFeedbackCard() {
    if (isLoadingFeedback) {
      return Card(
        color: isDarkTheme ? Colors.grey[800] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (latestFeedback == null) {
      return Card(
        color: isDarkTheme ? Colors.grey[800] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.quiz_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No Interview Taken Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkTheme ? Colors.white70 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Take your first interview to see feedback here',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final feedback = latestFeedback!['feedback'] ?? {};
    final strengths = List<String>.from(feedback['strengths'] ?? []);
    final weaknesses = List<String>.from(feedback['weaknesses'] ?? []);
    final suggestions = List<String>.from(feedback['suggestions'] ?? []);
    final confidenceScore = feedback['confidence_score'] ?? 0;

    DateTime? parsedDate;
    if (feedbackDate != null) {
      try {
        parsedDate = DateTime.parse(feedbackDate!);
      } catch (e) {
        print('Error parsing date: $e');
      }
    }

    return Card(
      color: isDarkTheme ? Colors.grey[800] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Latest Interview Feedback',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkTheme ? Colors.white : Colors.black,
                        ),
                      ),
                      if (parsedDate != null)
                        Text(
                          'Taken on ${parsedDate.day}/${parsedDate.month}/${parsedDate.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Confidence Score
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.purple),
                  const SizedBox(width: 8),
                  Text(
                    'Confidence Score: $confidenceScore%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkTheme ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Quick Summary
            if (strengths.isNotEmpty) ...[
              _buildQuickSection('Strengths', strengths.take(2).toList(), Colors.green, Icons.check_circle),
              const SizedBox(height: 8),
            ],
            
            if (weaknesses.isNotEmpty) ...[
              _buildQuickSection('Areas to Improve', weaknesses.take(2).toList(), Colors.orange, Icons.warning_amber),
              const SizedBox(height: 8),
            ],
            
            if (suggestions.isNotEmpty) ...[
              _buildQuickSection('Top Recommendations', suggestions.take(2).toList(), Colors.blue, Icons.lightbulb),
            ],
            
            const SizedBox(height: 12),
            
            // View Full Feedback Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  _showFullFeedbackDialog();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'View Full Feedback',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSection(String title, List<String> items, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '• ${item.length > 60 ? '${item.substring(0, 60)}...' : item}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }

  void _showFullFeedbackDialog() {
    if (latestFeedback == null) return;
    
    final feedback = latestFeedback!['feedback'] ?? {};
    final strengths = List<String>.from(feedback['strengths'] ?? []);
    final weaknesses = List<String>.from(feedback['weaknesses'] ?? []);
    final suggestions = List<String>.from(feedback['suggestions'] ?? []);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.analytics, color: Colors.blue),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Complete Feedback',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (strengths.isNotEmpty) ...[
                          _buildDialogSection('Strengths', strengths, Colors.green, Icons.check_circle),
                          const SizedBox(height: 16),
                        ],
                        if (weaknesses.isNotEmpty) ...[
                          _buildDialogSection('Areas for Improvement', weaknesses, Colors.orange, Icons.warning_amber),
                          const SizedBox(height: 16),
                        ],
                        if (suggestions.isNotEmpty) ...[
                          _buildDialogSection('Recommendations', suggestions, Colors.blue, Icons.lightbulb),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogSection(String title, List<String> items, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.asMap().entries.map((entry) => Container(
          margin: const EdgeInsets.only(bottom: 8),
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
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${entry.key + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.value,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Future<void> _clearFeedback() async {
    try {
      // Clear from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('latest_feedback');
      await prefs.remove('feedback_date');
      
      // Also clear from Firebase Firestore
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'latest_feedback': FieldValue.delete(),
          'feedback_date': FieldValue.delete(),
          'updated_at': FieldValue.serverTimestamp(),
        });
        print('Feedback cleared from Firebase');
      }
      
      setState(() {
        latestFeedback = null;
        feedbackDate = null;
      });
      
      print('Feedback cleared successfully');
    } catch (e) {
      print('Error clearing feedback: $e');
      // Still update UI even if clearing fails
      setState(() {
        latestFeedback = null;
        feedbackDate = null;
      });
    }
  }

  // FIXED: Navigate to Upload Screen
  Future<void> _takeInterview() async {
    try {
      // Clear previous feedback when starting new interview
      await _clearFeedback();
      
      // Use WidgetsBinding to ensure navigation happens after current frame
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushNamed(context, '/upload').catchError((error) {
              // If route doesn't exist, show error message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Upload screen route not found. Please check your main.dart routing configuration.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              print('Navigation error: $error');
            });
          }
        });
      }
    } catch (e) {
      print('Error navigating to upload: $e');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error navigating to interview screen'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    }
  }

  // FIXED: Proper logout with Firebase Auth
  Future<void> _logout() async {
    if (isLoggingOut) return; // Prevent multiple calls
    
    setState(() {
      isLoggingOut = true;
    });

    try {
      // Sign out from Firebase Auth
      await _auth.signOut();
      
      // Clear only session data from SharedPreferences (NOT feedback)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_name');
      await prefs.remove('user_email');
      // Keep feedback and theme preferences - they are user-specific and stored in Firebase
      
      print('User logged out successfully');
      
      // Use WidgetsBinding to ensure navigation happens after current frame
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          }
        });
      }
    } catch (e) {
      print('Error during logout: $e');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Logout error: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() {
              isLoggingOut = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingUserData) {
      return Scaffold(
        backgroundColor: isDarkTheme ? Colors.grey[900] : Colors.grey[50],
        appBar: AppBar(
          title: const Text('Settings / Profile'),
          backgroundColor: isDarkTheme ? Colors.grey[800] : null,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Theme(
      data: isDarkTheme ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: isDarkTheme ? Colors.grey[900] : Colors.grey[50],
        appBar: AppBar(
          title: const Text('Settings / Profile'),
          backgroundColor: isDarkTheme ? Colors.grey[800] : null,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Info Card
              Card(
                color: isDarkTheme ? Colors.grey[800] : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            child: Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkTheme ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userEmail,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Resume Card
              Card(
                color: isDarkTheme ? Colors.grey[800] : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                  title: Text(
                    'Resume.pdf',
                    style: TextStyle(
                      color: isDarkTheme ? Colors.white : Colors.black,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_red_eye, color: Colors.blue),
                    onPressed: () {
                      // TODO: Implement resume viewing functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Resume viewing will be implemented soon'),
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Feedback Section
              _buildFeedbackCard(),
              
              const SizedBox(height: 24),
              
              // Settings
              Card(
                color: isDarkTheme ? Colors.grey[800] : Colors.white,
                child: Column(
                  children: [
                    SwitchListTile(
                      value: true,
                      onChanged: (val) {
                        // TODO: Implement camera-based evaluation toggle
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Camera evaluation settings will be implemented soon'),
                          ),
                        );
                      },
                      title: Text(
                        'Camera-based Evaluation',
                        style: TextStyle(
                          color: isDarkTheme ? Colors.white : Colors.black,
                        ),
                      ),
                      secondary: const Icon(
                        Icons.videocam,
                        color: Colors.blue,
                      ),
                    ),
                    SwitchListTile(
                      value: isDarkTheme,
                      onChanged: _toggleTheme,
                      title: Text(
                        'Dark Theme',
                        style: TextStyle(
                          color: isDarkTheme ? Colors.white : Colors.black,
                        ),
                      ),
                      secondary: Icon(
                        isDarkTheme ? Icons.dark_mode : Icons.light_mode,
                        color: isDarkTheme ? Colors.orange : Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // FIXED: Take Interview Button 
              ElevatedButton(
                onPressed: _takeInterview, // Changed from direct navigation
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: const Text(
                  'Take Interview',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // FIXED: Logout Button with loading state
              ElevatedButton(
                onPressed: isLoggingOut ? null : _logout, // Disable when logging out
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: isLoggingOut 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Logout',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}