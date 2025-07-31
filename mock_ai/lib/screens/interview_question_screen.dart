import 'dart:io';
import 'dart:collection';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'facial_body_analysis_screen.dart';

// Video Processing Queue Item
class VideoProcessingTask {
  final String videoPath;
  final String question;
  final int questionIndex;
  final String sectionType;
  final DateTime timestamp;
  final Completer<Map<String, dynamic>> completer;
  int retryCount;

  VideoProcessingTask({
    required this.videoPath,
    required this.question,
    required this.questionIndex,
    required this.sectionType,
    required this.timestamp,
    int retryCount = 0,
  }) : completer = Completer<Map<String, dynamic>>(),
       retryCount = retryCount;

  Future<Map<String, dynamic>> get result => completer.future;
}

// Video Processing Service
class VideoProcessingService {
  static final VideoProcessingService _instance = VideoProcessingService._internal();
  factory VideoProcessingService() => _instance;
  VideoProcessingService._internal();

  final Queue<VideoProcessingTask> _processingQueue = Queue<VideoProcessingTask>();
  final Map<int, Map<String, dynamic>> _results = {};
  bool _isProcessing = false;

  // Add video to processing queue
  Future<void> addVideoForProcessing(VideoProcessingTask task) async {
    print("📥 Adding video to queue: Question ${task.questionIndex}");
    _processingQueue.add(task);
    _processQueue();
  }

  // Process queue
  Future<void> _processQueue() async {
    if (_isProcessing || _processingQueue.isEmpty) return;
    
    _isProcessing = true;
    
    while (_processingQueue.isNotEmpty) {
      final task = _processingQueue.removeFirst();
      await _processVideo(task);
    }
    
    _isProcessing = false;
  }

  // Process individual video
  Future<void> _processVideo(VideoProcessingTask task) async {
    try {
      print("🎬 Processing video for question ${task.questionIndex}");
      
      final uri = Uri.parse('http://192.168.18.47:8000/emotion/analyze-single');
      final request = http.MultipartRequest('POST', uri);

      // Check if file exists
      if (!File(task.videoPath).existsSync()) {
        throw Exception("Video file not found: ${task.videoPath}");
      }

      // Add video file
      request.files.add(
        await http.MultipartFile.fromPath('video', task.videoPath),
      );

      // Add form fields
      request.fields['question'] = task.question;
      request.fields['question_index'] = task.questionIndex.toString();

      print("📤 Sending request for question ${task.questionIndex}...");
      
      final response = await request.send().timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw TimeoutException('Request timeout'),
      );
      
      final resBody = await http.Response.fromStream(response);

      print("📊 Response Status: ${resBody.statusCode}");

      if (resBody.statusCode == 200) {
        final result = jsonDecode(resBody.body);
        
        // Store successful result
        _results[task.questionIndex] = {
          'question_index': task.questionIndex,
          'question': task.question,
          'section_type': task.sectionType,
          'analysis_result': result,
          'timestamp': task.timestamp.millisecondsSinceEpoch,
          'status': 'completed',
        };

        task.completer.complete(_results[task.questionIndex]!);
        print("✅ Successfully processed question ${task.questionIndex}");
        
      } else {
        throw Exception("HTTP ${resBody.statusCode}: ${resBody.body}");
      }
      
    } catch (e) {
      print("❌ Error processing question ${task.questionIndex}: $e");
      
      // Retry logic
      if (task.retryCount < 2) {
        task.retryCount++;
        print("🔄 Retrying question ${task.questionIndex} (attempt ${task.retryCount + 1})");
        
        // Add back to queue for retry
        await Future.delayed(Duration(seconds: task.retryCount * 2));
        _processingQueue.add(task);
        return;
      }
      
      // Max retries reached - store error result
      _results[task.questionIndex] = {
        'question_index': task.questionIndex,
        'question': task.question,
        'section_type': task.sectionType,
        'analysis_result': {
          'success': false,
          'error': e.toString(),
          'analysis': null,
        },
        'timestamp': task.timestamp.millisecondsSinceEpoch,
        'status': 'failed',
      };

      task.completer.complete(_results[task.questionIndex]!);
    }
  }

  // Get all results
  Map<int, Map<String, dynamic>> getAllResults() => Map.from(_results);

  // Wait for all processing to complete
  Future<void> waitForAllProcessing() async {
    while (_isProcessing || _processingQueue.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  // Get processing status
  Map<String, dynamic> getProcessingStatus() {
    return {
      'is_processing': _isProcessing,
      'queue_length': _processingQueue.length,
      'completed_count': _results.length,
    };
  }

  // Clear results (for cleanup)
  void clearResults() {
    _results.clear();
  }
}

class InterviewQuestionScreen extends StatefulWidget {
  final List<String> technicalQuestions;
  final List<String> behaviouralQuestions;

  const InterviewQuestionScreen({
    super.key,
    required this.technicalQuestions,
    required this.behaviouralQuestions,
  });

  @override
  State<InterviewQuestionScreen> createState() => _InterviewQuestionScreenState();
}

enum InterviewSection {
  intro,
  technicalIntro,
  technical,
  behaviouralIntro,
  behavioural,
  complete,
}

class _InterviewQuestionScreenState extends State<InterviewQuestionScreen>
    with TickerProviderStateMixin {
  InterviewSection section = InterviewSection.intro;
  int currentTechnicalIndex = 0;
  int currentBehaviouralIndex = 0;
  bool isRecording = false;
  bool answerRecorded = false;
  bool isUploading = false;
  bool isNavigating = false; // ADD: Navigation state tracking

  late List<Map<String, dynamic>> technicalAnswers;
  late List<Map<String, dynamic>> behaviouralAnswers;
  
  // Processing service
  final VideoProcessingService _processingService = VideoProcessingService();
  
  // Processing status tracking
  final Map<int, String> _questionProcessingStatus = {};
  Timer? _statusUpdateTimer;

  CameraController? _cameraController;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  late Directory _tempDir;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _loadingController;
  late AnimationController _recordingController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _loadingAnimation;
  late Animation<double> _recordingAnimation;

  @override
  void initState() {
    super.initState();
    _initialize();
    _initializeAnimations();
    _startStatusUpdates();
    
    technicalAnswers = List.generate(widget.technicalQuestions.length, (index) => {
      'question': widget.technicalQuestions[index],
      'skipped': false,
      'videoPath': null,
    });
    behaviouralAnswers = List.generate(widget.behaviouralQuestions.length, (index) => {
      'question': widget.behaviouralQuestions[index],
      'skipped': false,
      'videoPath': null,
    });
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _loadingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _recordingController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.linear),
    );

    _recordingAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _recordingController, curve: Curves.easeInOut),
    );
  }

  void _startStatusUpdates() {
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !isNavigating) { // FIXED: Check navigation state
        setState(() {
          // Update UI with processing status
        });
      }
    });
  }

  Future<void> _initialize() async {
    try {
      _tempDir = await getTemporaryDirectory();
      await Permission.camera.request();
      await Permission.microphone.request();
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.length > 1 ? cameras[1] : cameras[0], // Use front camera if available
          ResolutionPreset.medium
        );
        await _cameraController!.initialize();
      }
      await _recorder.openRecorder();
      if (mounted) setState(() {});
    } catch (e) {
      print("❌ Initialization error: $e");
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    try {
      await _cameraController!.startVideoRecording();
      if (mounted) {
        setState(() {
          isRecording = true;
          answerRecorded = false;
        });
      }
    } catch (e) {
      print("❌ Recording start error: $e");
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null || !_cameraController!.value.isRecordingVideo) {
      return;
    }

    try {
      final file = await _cameraController!.stopVideoRecording();
      if (mounted) {
        setState(() {
          isRecording = false;
          answerRecorded = true;
        });

        final answerList = section == InterviewSection.technical ? technicalAnswers : behaviouralAnswers;
        final index = section == InterviewSection.technical ? currentTechnicalIndex : currentBehaviouralIndex;

        answerList[index]['videoPath'] = file.path;

        // Add to background processing queue
        await _addVideoToProcessingQueue(file.path, index);
      }
    } catch (e) {
      print("❌ Recording stop error: $e");
    }
  }

  Future<void> _addVideoToProcessingQueue(String videoPath, int questionIndex) async {
    try {
      // Get current question details
      String currentQuestion;
      int globalQuestionIndex;
      String sectionType;
      
      if (section == InterviewSection.technical) {
        currentQuestion = widget.technicalQuestions[currentTechnicalIndex];
        globalQuestionIndex = currentTechnicalIndex;
        sectionType = 'technical';
      } else {
        currentQuestion = widget.behaviouralQuestions[currentBehaviouralIndex];
        globalQuestionIndex = widget.technicalQuestions.length + currentBehaviouralIndex;
        sectionType = 'behavioural';
      }

      // Create processing task
      final task = VideoProcessingTask(
        videoPath: videoPath,
        question: currentQuestion,
        questionIndex: globalQuestionIndex,
        sectionType: sectionType,
        timestamp: DateTime.now(),
      );

      // Update status
      _questionProcessingStatus[globalQuestionIndex] = 'processing';

      // Add to queue
      await _processingService.addVideoForProcessing(task);
      
      // Listen for completion (optional - for status updates)
      task.result.then((result) {
        if (mounted && !isNavigating) {
          setState(() {
            _questionProcessingStatus[globalQuestionIndex] = 
                result['status'] == 'completed' ? 'completed' : 'failed';
          });
        }
      }).catchError((error) {
        if (mounted && !isNavigating) {
          setState(() {
            _questionProcessingStatus[globalQuestionIndex] = 'failed';
          });
        }
      });

      print("📥 Video added to processing queue: Question $globalQuestionIndex");
      
    } catch (e) {
      print("❌ Error adding video to queue: $e");
      
      // Add error result immediately
      int globalQuestionIndex = section == InterviewSection.technical 
          ? currentTechnicalIndex 
          : widget.technicalQuestions.length + currentBehaviouralIndex;
          
      _questionProcessingStatus[globalQuestionIndex] = 'failed';
    }
  }

  void _skipQuestion() {
    final answerList = section == InterviewSection.technical ? technicalAnswers : behaviouralAnswers;
    final index = section == InterviewSection.technical ? currentTechnicalIndex : currentBehaviouralIndex;
    answerList[index]['skipped'] = true;
    
    // Add skipped status to processing service results
    int globalQuestionIndex = section == InterviewSection.technical 
        ? currentTechnicalIndex 
        : widget.technicalQuestions.length + currentBehaviouralIndex;
        
    _questionProcessingStatus[globalQuestionIndex] = 'skipped';
    
    _nextQuestion();
  }

  void _nextQuestion() {
    if (mounted && !isNavigating) {
      setState(() {
        if (section == InterviewSection.technical) {
          if (currentTechnicalIndex < widget.technicalQuestions.length - 1) {
            currentTechnicalIndex++;
          } else {
            section = InterviewSection.behaviouralIntro;
          }
        } else if (section == InterviewSection.behavioural) {
          if (currentBehaviouralIndex < widget.behaviouralQuestions.length - 1) {
            currentBehaviouralIndex++;
          } else {
            section = InterviewSection.complete;
          }
        }
        answerRecorded = false;
        isRecording = false;
      });
    }
  }

  Future<void> _navigateToResults() async {
    if (isNavigating) return; // FIXED: Prevent multiple navigation calls
    
    setState(() {
      isUploading = true;
      isNavigating = true; // FIXED: Set navigation state
    });

    try {
      print("⏳ Waiting for all video processing to complete...");
      
      // FIXED: Add timeout to prevent infinite waiting
      await _processingService.waitForAllProcessing().timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          print("⚠️ Processing timeout - continuing with available results");
        },
      );
      
      // Get all results
      final allResults = _processingService.getAllResults();
      
      // Convert to list format expected by analysis screen
      List<Map<String, dynamic>> allAnalysisResults = [];
      
      allResults.forEach((questionIndex, result) {
        allAnalysisResults.add(result);
      });
      
      // Add skipped questions
      _questionProcessingStatus.forEach((questionIndex, status) {
        if (status == 'skipped' && !allResults.containsKey(questionIndex)) {
          String question;
          String sectionType;
          
          if (questionIndex < widget.technicalQuestions.length) {
            question = widget.technicalQuestions[questionIndex];
            sectionType = 'technical';
          } else {
            question = widget.behaviouralQuestions[questionIndex - widget.technicalQuestions.length];
            sectionType = 'behavioural';
          }
          
          allAnalysisResults.add({
            'question_index': questionIndex,
            'question': question,
            'section_type': sectionType,
            'analysis_result': {
              'success': true,
              'skipped': true,
              'analysis': null,
            },
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'status': 'skipped',
          });
        }
      });

      print("📊 Navigating to results with ${allAnalysisResults.length} analysis results");
      
      if (mounted) {
        // FIXED: Use pushReplacement to prevent back navigation issues
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FacialBodyAnalysisScreen(
              result: {
                'interview_complete': true,
                'total_questions': widget.technicalQuestions.length + widget.behaviouralQuestions.length,
                'technical_questions': widget.technicalQuestions.length,
                'behavioural_questions': widget.behaviouralQuestions.length,
                'all_analysis_results': allAnalysisResults,
                'processing_timestamp': DateTime.now().millisecondsSinceEpoch,
                'processing_status': _processingService.getProcessingStatus(),
              },
            ),
          ),
        );
      }
    } catch (e) {
      print("❌ Navigation error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Navigation failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          isUploading = false;
          isNavigating = false;
        });
      }
    }
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback onPressed,
    bool isPrimary = true,
    IconData? icon,
  }) {
    final textColor = isPrimary ? Colors.white : Colors.black87;
    final iconColor = isPrimary ? Colors.white : Colors.black87;

    return Container(
      width: double.infinity,
      decoration: isPrimary
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.blue[600]!, Colors.blue[700]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            )
          : BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[400]!, width: 1.5),
            ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingButton() {
    return AnimatedBuilder(
      animation: _recordingAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _recordingAnimation.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.red[600]!, Colors.red[700]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(60),
                onTap: _stopRecording,
                child: const Center(
                  child: Icon(
                    Icons.stop,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProcessingStatusIndicator() {
    final status = _processingService.getProcessingStatus();
    final queueLength = status['queue_length'] as int;
    final completedCount = status['completed_count'] as int;
    
    if (queueLength == 0 && completedCount == 0) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          if (queueLength > 0) ...[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue[600],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              queueLength > 0 
                  ? 'Processing $queueLength video${queueLength > 1 ? 's' : ''} in background...'
                  : 'All videos processed ✓',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    int totalQuestions = widget.technicalQuestions.length + widget.behaviouralQuestions.length;
    int currentProgress = 0;
    
    if (section == InterviewSection.technical) {
      currentProgress = currentTechnicalIndex;
    } else if (section == InterviewSection.behavioural) {
      currentProgress = widget.technicalQuestions.length + currentBehaviouralIndex;
    } else if (section == InterviewSection.complete) {
      currentProgress = totalQuestions;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${currentProgress + 1} of $totalQuestions',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${((currentProgress / totalQuestions) * 100).round()}%',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: currentProgress / totalQuestions,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingAnimation() {
    final processingStatus = _processingService.getProcessingStatus();
    final queueLength = processingStatus['queue_length'] as int;
    final completedCount = processingStatus['completed_count'] as int;
    
    return AnimatedBuilder(
      animation: _loadingAnimation,
      builder: (context, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  transform: GradientRotation(_loadingAnimation.value * 6.28),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Center(
                  child: Icon(
                    Icons.analytics_outlined,
                    color: Colors.blue,
                    size: 60,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: const Text(
                    'Preparing Your Results...',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              queueLength > 0 
                  ? 'Processing $queueLength remaining videos...'
                  : 'Finalizing $completedCount analyzed responses',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuestion(String question, bool isLast) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withOpacity(0.1),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  section == InterviewSection.technical 
                      ? Icons.code 
                      : Icons.psychology,
                  color: Colors.blue[700],
                  size: 28,
                ),
                const SizedBox(height: 12),
                Text(
                  section == InterviewSection.technical 
                      ? 'Technical Question' 
                      : 'Behavioral Question',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.25,
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      question,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          if (isRecording)
            Column(
              children: [
                _buildRecordingButton(),
                const SizedBox(height: 16),
                Text(
                  'Recording in progress...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            )
          else if (answerRecorded)
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withOpacity(0.2),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Recording saved! Processing in background...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildGradientButton(
                    text: isLast ? 'Complete Interview' : 'Next Question',
                    onPressed: _nextQuestion,
                    icon: isLast ? Icons.done_all : Icons.arrow_forward,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildGradientButton(
                    text: 'Start Recording',
                    onPressed: _startRecording,
                    icon: Icons.videocam,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildGradientButton(
                    text: 'Skip',
                    onPressed: _skipQuestion,
                    isPrimary: false,
                    icon: Icons.skip_next,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildIntroSection(String title, String subtitle, VoidCallback onPressed) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 30),
        Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: _buildGradientButton(
            text: 'Continue',
            onPressed: onPressed,
            icon: Icons.arrow_forward,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Return early if navigating to prevent UI rebuilds
    if (isNavigating) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(color: Colors.white),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    Widget content;

    switch (section) {
      case InterviewSection.intro:
        content = _buildIntroSection(
          'Welcome to Your Interview',
          'Get ready to showcase your skills and personality',
          () => setState(() => section = InterviewSection.technicalIntro),
        );
        break;

      case InterviewSection.technicalIntro:
        content = _buildIntroSection(
          'Technical Questions',
          'Demonstrate your technical expertise and problem-solving skills',
          () {
            setState(() {
              section = widget.technicalQuestions.isEmpty
                  ? InterviewSection.behaviouralIntro
                  : InterviewSection.technical;
            });
          },
        );
        break;

      case InterviewSection.technical:
        content = widget.technicalQuestions.isEmpty
            ? const Center(
                child: Text(
                  "No technical questions available.",
                  style: TextStyle(color: Colors.black87, fontSize: 18),
                ),
              )
            : _buildQuestion(
                widget.technicalQuestions[currentTechnicalIndex],
                currentTechnicalIndex == widget.technicalQuestions.length - 1,
              );
        break;

      case InterviewSection.behaviouralIntro:
        content = _buildIntroSection(
          'Behavioral Questions',
          'Share your experiences and demonstrate your soft skills',
          () {
            setState(() {
              section = widget.behaviouralQuestions.isEmpty
                  ? InterviewSection.complete
                  : InterviewSection.behavioural;
            });
          },
        );
        break;

      case InterviewSection.behavioural:
        content = widget.behaviouralQuestions.isEmpty
            ? const Center(
                child: Text(
                  "No behavioral questions available.",
                  style: TextStyle(color: Colors.black87, fontSize: 18),
                ),
              )
            : _buildQuestion(
                widget.behaviouralQuestions[currentBehaviouralIndex],
                currentBehaviouralIndex == widget.behaviouralQuestions.length - 1,
              );
        break;

      case InterviewSection.complete:
        if (!isUploading) {
          // FIXED: Use post frame callback to prevent state changes during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateToResults();
          });
        }
        content = _buildLoadingAnimation();
        break;
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar with Blue Gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    if (section != InterviewSection.intro && section != InterviewSection.complete)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    Expanded(
                      child: Text(
                        section == InterviewSection.complete
                            ? 'Processing Results'
                            : 'Mock Interview',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (section != InterviewSection.intro && section != InterviewSection.complete)
                      const SizedBox(width: 48),
                  ],
                ),
              ),
              
              // Progress Indicator
              if (section == InterviewSection.technical || section == InterviewSection.behavioural)
                _buildProgressIndicator(),
              
              // Processing Status Indicator
              _buildProcessingStatusIndicator(),
              
              // Main Content
              Expanded(
                child: section == InterviewSection.technical || section == InterviewSection.behavioural
                    ? content
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: Container(
                          constraints: BoxConstraints(
                            minHeight: MediaQuery.of(context).size.height - 200,
                          ),
                          child: content,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // FIXED: Proper cleanup order
    _statusUpdateTimer?.cancel();
    _pulseController.dispose();
    _loadingController.dispose();
    _recordingController.dispose();
    
    // Cleanup camera and recorder
    _cameraController?.dispose();
    _recorder.closeRecorder();
    
    // Clear processing service results
    _processingService.clearResults();
    
    super.dispose();
  }
}