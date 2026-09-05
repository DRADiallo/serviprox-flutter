import 'package:flutter/material.dart';
class ReparationScreen extends StatelessWidget {
  const ReparationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Réparation")),
      body: const Center(child: Text("Réparation — En cours...")),
    );
  }
}