import 'package:flutter/material.dart';
class SoinsScreen extends StatelessWidget {
  const SoinsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Soins domicile")),
      body: const Center(child: Text("Soins — En cours...")),
    );
  }
}