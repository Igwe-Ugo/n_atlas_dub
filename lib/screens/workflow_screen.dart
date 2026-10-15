import 'package:flutter/material.dart';

class WorkflowScreen extends StatelessWidget {
  const WorkflowScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        toolbarHeight: 70,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                image: DecorationImage(
                  fit: BoxFit.contain,
                  image: AssetImage('assets/images/natlas_logo.jpg'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'N-ATLAS',
                  style: TextStyle(
                    color: Color(0xFF2C248A),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  'Video Localizer',
                  style: TextStyle(color: Color(0xFF2C248A), fontSize: 15),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.black87),
            tooltip: 'About N-ATLaS Dub',
            onPressed: () => Navigator.pushNamed(context, '/about'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
            tooltip: 'API settings',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Turn your English marketing videos into engaging local language videos in minutes.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: const [
                    WorkflowStepTile(
                      icon: Icons.play_circle_fill,
                      title: 'Upload Video',
                      subtitle: 'MP4 videos up to 100 MB and 90 seconds',
                      iconColor: Color.fromARGB(255, 1, 125, 225),
                    ),
                    WorkflowStepTile(
                      icon: Icons.translate,
                      title: 'Select Target Language',
                      subtitle: 'Yoruba, Igbo or Hausa with Nigerian voices',
                      iconColor: Color.fromARGB(255, 1, 121, 85),
                    ),
                    WorkflowStepTile(
                      icon: Icons.description,
                      title: 'AI Transcription',
                      subtitle: 'English speech to text',
                      iconColor: Color.fromARGB(255, 1, 125, 225),
                    ),
                    WorkflowStepTile(
                      icon: Icons.g_translate,
                      title: 'AI Translation',
                      subtitle: 'Powered by N-ATLAS',
                      iconColor: Color.fromARGB(255, 1, 121, 85),
                    ),
                    WorkflowStepTile(
                      icon: Icons.mic,
                      title: 'Generate Voice',
                      subtitle: 'Natural and clear speech',
                      iconColor: Color.fromARGB(255, 1, 70, 49),
                    ),
                    WorkflowStepTile(
                      icon: Icons.video_collection,
                      title: 'Create Final Video',
                      subtitle: 'Voiceover + Subtitles',
                      iconColor: Color.fromARGB(255, 1, 36, 66),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/uploadVideo'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('Start Now'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkflowStepTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;

  const WorkflowStepTile({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
