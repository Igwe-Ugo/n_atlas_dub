import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class CompletionCelebrationScreen extends StatelessWidget {
  const CompletionCelebrationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // Smooth transition from top-center to bottom-center
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors
                .grey[700]!, // Adjust the shade of grey here (e.g., 100 to 400)
          ],
          stops: const [
            0.5, // White stays pure until exactly 50% (middle) of the screen
            1.0, // The transition ends at the very bottom
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.contain,
                      image: AssetImage('assets/images/natlas_logo.jpg'),
                    ),
                  ),
                ),
                const Text(
                  'N-ATLAS',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B),
                    letterSpacing: 1.1,
                  ),
                ),
                const Text(
                  'Video Localizer',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1E1B4B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 36),

                // Clapboard Icon Graphic Placeholder
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Lottie.asset(
                    'assets/json/wired-flat-499-clapperboard-play-open-hover-pinch.json',
                  ),
                ),
                const SizedBox(height: 28),

                const Text(
                  'Local stories.\nBigger connections.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
                const Spacer(),

                // Back To Home Button
                ElevatedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/dashboard',
                    (route) => false,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2C248A),
                    elevation: 0,
                    //
                    //side: const BorderSide(color: Color(0xFFE2E8F0)),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
