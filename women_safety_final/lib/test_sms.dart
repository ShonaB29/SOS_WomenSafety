import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const TestApp());

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('SMS Test')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () async {
                  // TEST 1: Simple SMS
                  Uri uri = Uri(
                    scheme: 'sms',
                    path: '100',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    debugPrint('❌ Test 1 failed');
                  }
                },
                child: const Text('Test 1: Open SMS to 100'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  // TEST 2: SMS with message
                  String msg = 'Hello';
                  Uri uri = Uri(
                    scheme: 'sms',
                    path: '100',
                    queryParameters: {'body': msg},
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    debugPrint('❌ Test 2 failed');
                  }
                },
                child: const Text('Test 2: SMS with "Hello"'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  // TEST 3: Different format
                  String msg = 'Test';
                  Uri uri = Uri.parse('sms:100?body=$msg');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    debugPrint('❌ Test 3 failed');
                  }
                },
                child: const Text('Test 3: Alternative format'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
