import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About N-ATLaS Dub')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'N-ATLAS Dub',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'N-ATLaS is an initiative of the Federal Ministry of '
              'Communications, Innovation and Digital Economy, and powered '
              'by Awarri Technologies.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            SizedBox(height: 20),
            Text('Backend project'),
            SelectableText('https://github.com/KutuDev/natlas-dub'),
          ],
        ),
      ),
    );
  }
}
