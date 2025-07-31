import 'package:flutter/material.dart';

class HistoryComparisonScreen extends StatelessWidget {
  const HistoryComparisonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History & Comparison')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Past Sessions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: const [
                  ListTile(
                    leading: Icon(Icons.history, color: Colors.blue),
                    title: Text('Session 1 - 2024-07-01 10:00'),
                  ),
                  ListTile(
                    leading: Icon(Icons.history, color: Colors.blue),
                    title: Text('Session 2 - 2024-07-05 14:30'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Confidence/Fluency Growth'),
            Container(
              height: 120,
              color: Colors.blue.shade50,
              child: const Center(child: Text('Line Chart Placeholder')),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
              ),
              child: const Text(
                'Compare Sessions',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
