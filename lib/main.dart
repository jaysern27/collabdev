import 'package:flutter/material.dart';

import 'external_data_sources/firebase.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseDataSource.instance.initialize();

  runApp(const CultureGuideApp());
}

class CultureGuideApp extends StatelessWidget {
  const CultureGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CultureGuide',
      home: const Scaffold(
        body: Center(
          child: Text(
            'CultureGuide',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}