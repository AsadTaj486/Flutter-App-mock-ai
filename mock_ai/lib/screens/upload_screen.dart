import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'interview_question_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String? resumeFileName;
  String? jobDescFileName;
  File? resumeFile;
  File? jobDescFile;
  Uint8List? resumeFileBytes;
  Uint8List? jobDescFileBytes;
  bool isLoadingQuestions = false;
  bool isPickerActive = false;

  Future<void> pickResume() async {
    if (isPickerActive) return;
    setState(() => isPickerActive = true);

    if (await Permission.storage.request().isGranted) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          resumeFileName = result.files.single.name;
          if (kIsWeb) {
            resumeFileBytes = result.files.single.bytes;
            resumeFile = null;
          } else {
            resumeFile = File(result.files.single.path!);
            resumeFileBytes = null;
          }
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission is required to pick files.')),
      );
    }

    setState(() => isPickerActive = false);
  }

  Future<void> pickJobDesc() async {
    if (isPickerActive) return;
    setState(() => isPickerActive = true);

    if (await Permission.storage.request().isGranted) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          jobDescFileName = result.files.single.name;
          if (kIsWeb) {
            jobDescFileBytes = result.files.single.bytes;
            jobDescFile = null;
          } else {
            jobDescFile = File(result.files.single.path!);
            jobDescFileBytes = null;
          }
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission is required to pick files.')),
      );
    }

    setState(() => isPickerActive = false);
  }

  Future<Map<String, dynamic>> uploadFile(File file, String endpoint) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://192.168.18.47:8000/$endpoint/upload'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    var response = await request.send();
    final res = await http.Response.fromStream(response);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> uploadFileWeb(Uint8List fileBytes, String fileName, String endpoint) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://192.168.18.47:8000/$endpoint/upload'),
    );
    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );
    var response = await request.send();
    final res = await http.Response.fromStream(response);
    return jsonDecode(res.body);
  }

  Future<List<String>> fetchQuestions(String resumeText, String jdText) async {
    final url = Uri.parse('http://192.168.18.47:8000/questions/generate');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'resume': resumeText, 'jd': jdText}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List<String> rawQuestions = List<String>.from(data['questions']);
      final filteredQuestions = rawQuestions.where((q) => q.trim().contains('?')).toList();
      return filteredQuestions;
    } else {
      throw Exception('Failed to load questions');
    }
  }

  Future<void> _startInterview() async {
    setState(() => isLoadingQuestions = true);

    try {
      String? resumeText;
      String? jdText;

      if (kIsWeb) {
        if (resumeFileBytes != null && jobDescFileBytes != null) {
          final resumeResponse = await uploadFileWeb(resumeFileBytes!, resumeFileName!, 'resume');
          final jdResponse = await uploadFileWeb(jobDescFileBytes!, jobDescFileName!, 'jd');
          resumeText = resumeResponse['text'] ?? '';
          jdText = jdResponse['text'] ?? '';
        }
      } else {
        if (resumeFile != null && jobDescFile != null) {
          final resumeResponse = await uploadFile(resumeFile!, 'resume');
          final jdResponse = await uploadFile(jobDescFile!, 'jd');
          resumeText = resumeResponse['text'] ?? '';
          jdText = jdResponse['text'] ?? '';
        }
      }

      final allQuestions = await fetchQuestions(resumeText ?? '', jdText ?? '');
      final technicalQuestions = allQuestions.take(3).toList();
      final behaviouralQuestions = allQuestions.skip(3).toList();

      if (technicalQuestions.isEmpty && behaviouralQuestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid questions were generated.')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InterviewQuestionScreen(
            technicalQuestions: technicalQuestions,
            behaviouralQuestions: behaviouralQuestions,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => isLoadingQuestions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canStart = resumeFileName != null && jobDescFileName != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF64B5F6),
              Color(0xFF1976D2),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Upload Documents',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _UploadCard(
                      title: 'Upload Resume',
                      icon: Icons.upload_file,
                      onTap: () {
                        if (!isPickerActive) pickResume();
                      },
                      fileName: resumeFileName,
                      uploadedText: 'Resume is uploaded',
                    ),
                    const SizedBox(height: 24),
                    _UploadCard(
                      title: 'Upload Job Description',
                      icon: Icons.description,
                      onTap: () {
                        if (!isPickerActive) pickJobDesc();
                      },
                      fileName: jobDescFileName,
                      uploadedText: 'Job description is uploaded',
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: canStart && !isLoadingQuestions ? _startInterview : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0D47A1),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        'Start Interview',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoadingQuestions)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final String? fileName;
  final String uploadedText;

  const _UploadCard({
    required this.title,
    required this.icon,
    required this.onTap,
    required this.fileName,
    required this.uploadedText,
  });

  @override
  Widget build(BuildContext context) {
    final bool uploaded = fileName != null;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: 40, color: Colors.blue),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              _FilePreviewCard(
                uploaded: uploaded,
                uploadedText: uploadedText,
                fileName: fileName,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilePreviewCard extends StatelessWidget {
  final bool uploaded;
  final String uploadedText;
  final String? fileName;

  const _FilePreviewCard({
    required this.uploaded,
    required this.uploadedText,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: uploaded ? Colors.green.shade50 : Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.insert_drive_file, color: uploaded ? Colors.green : Colors.blue),
        title: Text(
          uploaded ? uploadedText : 'No file selected',
          style: TextStyle(
            color: uploaded ? Colors.green : Colors.black,
            fontWeight: uploaded ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: uploaded && fileName != null
            ? Text(fileName!, style: const TextStyle(fontSize: 12))
            : null,
      ),
    );
  }
}
