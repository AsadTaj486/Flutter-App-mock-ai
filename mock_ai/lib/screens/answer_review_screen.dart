import 'package:flutter/material.dart';

class AnswerReviewScreen extends StatelessWidget {
  const AnswerReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Answer')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Transcribed Answer:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 16, color: Colors.black),
                children: [
                  const TextSpan(text: 'I am a software engineer with '),
                  TextSpan(
                    text: 'um',
                    style: TextStyle(backgroundColor: Colors.yellow.shade200),
                  ),
                  const TextSpan(text: ' 5 years of experience in '),
                  TextSpan(
                    text: 'like',
                    style: TextStyle(backgroundColor: Colors.yellow.shade200),
                  ),
                  const TextSpan(text: ' mobile development.'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/recording');
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Re-record'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/analysis');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
