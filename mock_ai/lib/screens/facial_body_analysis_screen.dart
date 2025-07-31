import 'package:flutter/material.dart';
import 'package:mock_ai/screens/automated_feedback_report_screen.dart';

class FacialBodyAnalysisScreen extends StatefulWidget {
  final Map<String, dynamic> result;

  const FacialBodyAnalysisScreen({super.key, required this.result});

  @override
  State<FacialBodyAnalysisScreen> createState() => _FacialBodyAnalysisScreenState();
}

class _FacialBodyAnalysisScreenState extends State<FacialBodyAnalysisScreen> {
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    // Initialize after frame is built to prevent build-time issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Debug print to see what data we're receiving
    print('FacialBodyAnalysisScreen received data: ${widget.result}');
    
    // Show loading while initializing
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'Facial & Body Analysis',
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
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Check if this is the new format with multiple analysis results
    if (widget.result['interview_complete'] == true && widget.result['all_analysis_results'] != null) {
      return _buildMultipleAnalysisView(context);
    }
    
    // Handle old format (single analysis)
    return _buildSingleAnalysisView(context);
  }

  // Handle multiple analysis results from InterviewQuestionScreen
  Widget _buildMultipleAnalysisView(BuildContext context) {
    final allResults = widget.result['all_analysis_results'] as List<Map<String, dynamic>>;
    final totalQuestions = widget.result['total_questions'] ?? 0;
    final technicalQuestions = widget.result['technical_questions'] ?? 0;
    final behaviouralQuestions = widget.result['behavioural_questions'] ?? 0;
    
    // Calculate overall metrics by averaging all successful analyses
    Map<String, dynamic> combinedAnalysis = _combineAllAnalyses(allResults);
    String combinedTranscript = _combineAllTranscripts(allResults);
    Map<String, dynamic> overallEvaluation = _calculateOverallEvaluation(allResults);
    
    return Scaffold(
      key: const ValueKey('multiple_analysis_scaffold'),
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Facial & Body Analysis',
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
      body: SafeArea(
        child: Column(
          children: [
            // Header Card - Fixed height
            Container(
              margin: const EdgeInsets.all(16),
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
                mainAxisSize: MainAxisSize.min, // FIXED: Prevent expansion
                children: [
                  const Icon(
                    Icons.psychology,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Interview Analysis Complete!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Analyzed $totalQuestions questions ($technicalQuestions technical, $behaviouralQuestions behavioral)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your facial expressions, body language, and answers have been comprehensively analyzed',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content area
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Overall Answer Evaluation Section
                  _buildAnswerEvaluationSection(overallEvaluation),

                  // Combined Transcript Section
                  if (combinedTranscript.isNotEmpty)
                    _buildTranscriptSection(combinedTranscript),

                  // Combined Analysis Cards
                  _buildAnalysisCard('Eye Contact', combinedAnalysis['eye_contact'], Icons.visibility, Colors.purple),
                  _buildAnalysisCard('Smile', combinedAnalysis['smile'], Icons.sentiment_satisfied, Colors.orange),
                  _buildAnalysisCard('Posture', combinedAnalysis['posture'], Icons.accessibility_new, Colors.green),
                  _buildAnalysisCard('Voice Emotion', combinedAnalysis['voice_emotion'], Icons.record_voice_over, Colors.red),
                  _buildAnalysisCard('Confidence', combinedAnalysis['confidence'], Icons.psychology_alt, Colors.indigo),
                  _buildAnalysisCard('Hand Movement', combinedAnalysis['hand_movement'], Icons.back_hand, Colors.teal),
                  _buildAnalysisCard('Head Nod', combinedAnalysis['head_nod'], Icons.face, Colors.brown),
                  
                  // Add combined emotion display
                  if (combinedAnalysis['emotion'] != null)
                    _buildEmotionCard('Overall Emotions', combinedAnalysis['emotion']),

                  const SizedBox(height: 24),

                  // Feedback Button
                  Container(
                    width: double.infinity,
                    height: 56,
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
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(
                        Icons.analytics_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                      label: const Text(
                        'View Detailed Feedback',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FeedbackScreen(result: combinedAnalysis),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Handle single analysis (backward compatibility)
  Widget _buildSingleAnalysisView(BuildContext context) {
    final analysis = widget.result['analysis'];
    final question = widget.result['question'];
    final answerEvaluation = widget.result['answer_evaluation'];
    final combinedTranscript = analysis?['combined_transcript'];
    final videosProcessed = widget.result['videos_processed'];
    final totalVideos = widget.result['total_videos'];

    if (analysis == null || analysis.isEmpty) {
      return Scaffold(
        key: const ValueKey('single_analysis_no_data_scaffold'),
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'Facial & Body Analysis',
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
        body: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Analysis Data',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No analysis data received from the backend',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      key: const ValueKey('single_analysis_scaffold'),
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Facial & Body Analysis',
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
      body: SafeArea(
        child: Column(
          children: [
            // Header Card - Fixed height
            Container(
              margin: const EdgeInsets.all(16),
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
                mainAxisSize: MainAxisSize.min, // FIXED: Prevent expansion
                children: [
                  const Icon(
                    Icons.psychology,
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
                  if (question != null && question.isNotEmpty) ...[
                    Text(
                      'Question: $question',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    videosProcessed != null && totalVideos != null
                        ? 'Processed $videosProcessed of $totalVideos videos'
                        : 'Your facial expressions and body language have been analyzed',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            
            // Scrollable content area
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Answer Evaluation Section
                  if (answerEvaluation != null)
                    _buildAnswerEvaluationSection(answerEvaluation),

                  // Transcript Section
                  if (combinedTranscript != null && combinedTranscript.isNotEmpty)
                    _buildTranscriptSection(combinedTranscript),

                  // Analysis Cards
                  _buildAnalysisCard('Eye Contact', analysis['eye_contact'], Icons.visibility, Colors.purple),
                  _buildAnalysisCard('Smile', analysis['smile'], Icons.sentiment_satisfied, Colors.orange),
                  _buildAnalysisCard('Posture', analysis['posture'], Icons.accessibility_new, Colors.green),
                  _buildAnalysisCard('Voice Emotion', analysis['voice_emotion'], Icons.record_voice_over, Colors.red),
                  _buildAnalysisCard('Confidence', analysis['confidence'], Icons.psychology_alt, Colors.indigo),
                  _buildAnalysisCard('Hand Movement', analysis['hand_movement'], Icons.back_hand, Colors.teal),
                  _buildAnalysisCard('Head Nod', analysis['head_nod'], Icons.face, Colors.brown),
                  
                  // Add emotion display if it exists
                  if (analysis['emotion'] != null)
                    _buildEmotionCard('Emotions', analysis['emotion']),

                  const SizedBox(height: 24),

                  // Feedback Button
                  Container(
                    width: double.infinity,
                    height: 56,
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
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(
                        Icons.analytics_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                      label: const Text(
                        'View Detailed Feedback',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FeedbackScreen(result: analysis),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Combine all analysis results into averaged metrics
  Map<String, dynamic> _combineAllAnalyses(List<Map<String, dynamic>> allResults) {
    List<Map<String, dynamic>> validResults = [];
    List<dynamic> allEmotions = [];

    // Filter successful analyses
    for (var result in allResults) {
      final analysisResult = result['analysis_result'];
      if (analysisResult != null && analysisResult['success'] == true && analysisResult['analysis'] != null && analysisResult['skipped'] != true) {
        validResults.add(analysisResult['analysis']);
        
        // Collect emotions
        if (analysisResult['analysis']['emotion'] != null) {
          if (analysisResult['analysis']['emotion'] is List) {
            allEmotions.addAll(analysisResult['analysis']['emotion']);
          }
        }
      }
    }

    if (validResults.isEmpty) {
      return {
        'eye_contact': 0.0,
        'smile': 0.0,
        'posture': 0.0,
        'confidence': 0.0,
        'hand_movement': 0.0,
        'head_nod': 0.0,
        'voice_emotion': 0.0,
        'emotion': allEmotions,
      };
    }

    // Calculate averages
    Map<String, double> sums = {
      'eye_contact': 0.0,
      'smile': 0.0,
      'posture': 0.0,
      'confidence': 0.0,
      'hand_movement': 0.0,
      'head_nod': 0.0,
      'voice_emotion': 0.0,
    };

    for (var result in validResults) {
      sums.forEach((key, value) {
        final resultValue = result[key];
        if (resultValue != null) {
          sums[key] = sums[key]! + (resultValue is num ? resultValue.toDouble() : 0.0);
        }
      });
    }

    // Calculate averages
    Map<String, dynamic> averages = {};
    sums.forEach((key, sum) {
      averages[key] = validResults.isNotEmpty ? (sum / validResults.length).toDouble() : 0.0;
    });

    averages['emotion'] = allEmotions;
    
    return averages;
  }

  // Combine all transcripts
  String _combineAllTranscripts(List<Map<String, dynamic>> allResults) {
    List<String> transcripts = [];
    
    for (var result in allResults) {
      final analysisResult = result['analysis_result'];
      if (analysisResult != null && analysisResult['success'] == true && analysisResult['analysis'] != null && analysisResult['skipped'] != true) {
        
        final transcript = analysisResult['analysis']['transcript'];
        if (transcript != null && transcript.toString().trim().isNotEmpty) {
          transcripts.add('Q${result['question_index'] + 1}: ${transcript.toString().trim()}');
        }
      }
    }
    
    return transcripts.join('\n\n');
  }

  // Calculate overall evaluation from all results
  Map<String, dynamic> _calculateOverallEvaluation(List<Map<String, dynamic>> allResults) {
    List<int> scores = [];
    List<String> feedbacks = [];
    List<String> suggestions = [];
    int totalQuestions = allResults.length;
    int analyzedQuestions = 0;
    int skippedQuestions = 0;

    for (var result in allResults) {
      final analysisResult = result['analysis_result'];
      
      if (analysisResult != null && analysisResult['success'] == true) {
        if (analysisResult['skipped'] == true) {
          skippedQuestions++;
        } else {
          analyzedQuestions++;
          final evaluation = analysisResult['answer_evaluation'];
          if (evaluation != null) {
            scores.add(evaluation['score'] ?? 0);
            if (evaluation['feedback'] != null && evaluation['feedback'].toString().isNotEmpty) {
              feedbacks.add('Q${result['question_index'] + 1}: ${evaluation['feedback']}');
            }
            if (evaluation['suggestions'] != null && evaluation['suggestions'].toString().isNotEmpty) {
              suggestions.add(evaluation['suggestions'].toString());
            }
          }
        }
      }
    }

    int averageScore = scores.isNotEmpty ? (scores.reduce((a, b) => a + b) / scores.length).round() : 0;
    
    String status = 'Unknown';
    if (averageScore >= 80) {
      status = 'Excellent';
    } else if (averageScore >= 70) {
      status = 'Good';
    } else if (averageScore >= 60) {
      status = 'Average';
    } else if (averageScore >= 40) {
      status = 'Needs Improvement';
    } else {
      status = 'Poor';
    }

    return {
      'status': status,
      'score': averageScore,
      'feedback': 'Overall performance across $analyzedQuestions analyzed questions (${skippedQuestions} skipped).\n\n${feedbacks.join('\n\n')}',
      'reasoning': 'Average score calculated from $analyzedQuestions responses out of $totalQuestions total questions.',
      'suggestions': suggestions.isNotEmpty ? suggestions.join(' ') : 'Continue practicing interview skills for better performance.',
    };
  }

  // UI METHODS (Complete implementations)
  Widget _buildAnswerEvaluationSection(Map<String, dynamic> evaluation) {
    final status = evaluation['status'] ?? 'Unknown';
    final score = evaluation['score'] ?? 0;
    final feedback = evaluation['feedback'] ?? '';
    final reasoning = evaluation['reasoning'] ?? '';
    final suggestions = evaluation['suggestions'] ?? '';

    // Determine color and icon based on status
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help_outline;

    switch (status.toLowerCase()) {
      case 'excellent':
      case 'good':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'average':
      case 'moderate':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case 'poor':
      case 'needs improvement':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case 'no audio':
        statusColor = Colors.grey;
        statusIcon = Icons.mic_off;
        break;
      case 'error':
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
        break;
    }

    return Column(
      children: [
        // Section Header
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Icon(Icons.quiz, color: Colors.blue[600], size: 24),
              const SizedBox(width: 8),
              Text(
                'Answer Evaluation',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),

        // Evaluation Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status and Score Row
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status: $status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Score: $score/100',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        '$score%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                // Feedback Section
                if (feedback.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.feedback, color: Colors.blue[600], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Feedback',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          feedback,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[700],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Reasoning Section
                if (reasoning.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb, color: Colors.orange[600], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Reasoning',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          reasoning,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange[700],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Suggestions Section
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tips_and_updates, color: Colors.green[600], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Suggestions',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          suggestions,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[700],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptSection(String transcript) {
    return Column(
      children: [
        // Section Header
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Icon(Icons.record_voice_over, color: Colors.blue[600], size: 24),
              const SizedBox(width: 8),
              Text(
                'Your Answer',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),

        // Transcript Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.text_snippet,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Speech Transcript',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'What you said during the interview',
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
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 200), // FIXED: Limit height
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      transcript,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisCard(String title, dynamic value, IconData icon, Color color) {
    double percentage = 0.0;
    if (value != null) {
      if (value is num) {
        percentage = value.toDouble();
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(percentage * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    _getStatusText(percentage),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionCard(String title, List<dynamic> emotions) {
    if (emotions.isEmpty) return const SizedBox.shrink();

    // Count emotion frequencies
    Map<String, int> emotionCounts = {};
    for (var emotion in emotions) {
      String emotionStr = emotion.toString().toLowerCase();
      emotionCounts[emotionStr] = (emotionCounts[emotionStr] ?? 0) + 1;
    }

    // Sort by frequency
    var sortedEmotions = emotionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.pink.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.mood,
                    color: Colors.pink,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Detected ${emotions.length} emotional states',
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sortedEmotions.take(6).map((entry) {
                String emotion = entry.key;
                int count = entry.value;
                Color emotionColor = _getEmotionColor(emotion);
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: emotionColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: emotionColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${emotion.capitalize()} ($count)',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: emotionColor,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(double percentage) {
    if (percentage >= 0.8) return 'Excellent';
    if (percentage >= 0.6) return 'Good';
    if (percentage >= 0.4) return 'Average';
    if (percentage >= 0.2) return 'Poor';
    return 'Very Poor';
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
      case 'joy':
        return Colors.yellow[700]!;
      case 'sad':
      case 'sadness':
        return Colors.blue[700]!;
      case 'angry':
      case 'anger':
        return Colors.red[700]!;
      case 'fear':
      case 'afraid':
        return Colors.purple[700]!;
      case 'surprise':
      case 'surprised':
        return Colors.orange[700]!;
      case 'disgust':
        return Colors.green[700]!;
      case 'neutral':
        return Colors.grey[700]!;
      case 'confident':
      case 'confidence':
        return Colors.indigo[700]!;
      case 'nervous':
      case 'anxiety':
        return Colors.amber[700]!;
      default:
        return Colors.teal[700]!;
    }
  }
}

// Extension to capitalize first letter
extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}