import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

// User model class matching your FastAPI response
class UserDetails {
  final String? id;
  final String? email;
  final String? name;
  final String? token;

  UserDetails({
    this.id,
    this.email,
    this.name,
    this.token,
  });

  factory UserDetails.fromJson(Map<String, dynamic> json) {
    return UserDetails(
      id: json['id']?.toString(),
      email: json['email']?.toString(),
      name: json['name']?.toString(),
      token: json['token']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'token': token,
    };
  }
}

class ApiService {
  static const String baseUrl = 'http://192.168.18.47:8000'; // Replace with your IP

  // Authentication Methods
  static Future<UserDetails?> login(String email, String password) async {
    try {
      print('Attempting login for: $email'); // Debug print
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      print('Login response status: ${response.statusCode}'); // Debug print
      print('Login response body: ${response.body}'); // Debug print

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        return UserDetails.fromJson(responseData);
      } else {
        print('Login failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  static Future<UserDetails?> signup(String email, String password, String name) async {
    try {
      print('Attempting signup for: $email'); // Debug print
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
        }),
      );

      print('Signup response status: ${response.statusCode}'); // Debug print
      print('Signup response body: ${response.body}'); // Debug print

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        return UserDetails.fromJson(responseData);
      } else {
        print('Signup failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Signup error: $e');
      return null;
    }
  }

  static Future<bool> logout() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Logout error: $e');
      return false;
    }
  }

  // Existing Methods
  static Future<Map<String, dynamic>> uploadResume(File file) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/resume/upload'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    var response = await request.send();
    final res = await http.Response.fromStream(response);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> uploadJD(File file) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/jd/upload'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    var response = await request.send();
    final res = await http.Response.fromStream(response);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> generateQuestions(String resume, String jd) async {
    final res = await http.post(
      Uri.parse('$baseUrl/questions/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'resume': resume, 'jd': jd}),
    );
    return jsonDecode(res.body);
  }

  // More functions for audio upload, feedback, etc...
}