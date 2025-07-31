import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Save user profile data after registration/login
  static Future<bool> saveUserProfile({
    required String name,
    required String email,
  }) async {
    try {
      if (currentUser == null) return false;

      await _firestore.collection('users').doc(currentUser!.uid).set({
        'name': name,
        'email': email,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge: true will update existing data

      return true;
    } catch (e) {
      print('Error saving user profile: $e');
      return false;
    }
  }

  // Get user profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (currentUser == null) return null;

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Save interview feedback
  static Future<bool> saveFeedback({
    required Map<String, dynamic> feedbackData,
  }) async {
    try {
      if (currentUser == null) return false;

      // Save individual interview record
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('interviews')
          .add({
        'feedback': feedbackData,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Update latest feedback in user document
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .update({
        'latest_feedback': feedbackData,
        'last_interview_date': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error saving feedback: $e');
      return false;
    }
  }

  // Get latest feedback
  static Future<Map<String, dynamic>?> getLatestFeedback() async {
    try {
      if (currentUser == null) return null;

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists) {
        Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
        return userData['latest_feedback'];
      }
      return null;
    } catch (e) {
      print('Error getting latest feedback: $e');
      return null;
    }
  }

  // Get interview history
  static Future<List<Map<String, dynamic>>> getInterviewHistory() async {
    try {
      if (currentUser == null) return [];

      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('interviews')
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Add document ID
        return data;
      }).toList();
    } catch (e) {
      print('Error getting interview history: $e');
      return [];
    }
  }

  // Check if user is logged in
  static bool isLoggedIn() => currentUser != null;

  // Logout
  static Future<void> logout() async {
    await _auth.signOut();
  }
}