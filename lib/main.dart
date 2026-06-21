import 'package:flutter/material.dart';

void main() {
  runApp(const OTAApp());
}

class OTAApp extends StatelessWidget {
  const OTAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OTA Cheshire',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Olympic Taekwondo Academy'),
      ),
      body: const Center(
        child: Text('Login Screen'),
      ),
    );
  }
}