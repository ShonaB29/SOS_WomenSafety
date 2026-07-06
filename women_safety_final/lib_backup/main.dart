import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Women Safety',
      theme: ThemeData(primarySwatch: Colors.pink),
      home: const SafeArea(
        child: Scaffold(
          body: Center(
            child: Text('Test - If you see this, app works!'),
          ),
        ),
      ),
    );
  }
}
