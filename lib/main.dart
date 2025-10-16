import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'Routes/StatisticsPage.dart';
import 'Routes/TravelLogPage.dart';
import 'Routes/AddDetailsPage.dart';
import 'Routes/TripDetailsPage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable immersiveSticky mode to hide system UI
  // while still allowing swipe gestures to bring it back temporarily.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(MyApp());
}

/// The root widget of the application.
/// Sets up global routes and app-wide configuration.
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travel Log',
      debugShowCheckedModeBanner: false, // Hides the debug banner
      initialRoute: '/', // Default route
      routes: {
        '/': (context) => HomePage(),
        '/travelLog': (context) => TravelLogPage(),
        '/addDetails': (context) => AddDetails(),
        '/statistic': (context) => StatisticsPage(),
      },
    );
  }
}

/// The initial screen (Home Page) displayed when the app launches.
/// Shows the app icon, title, tagline, and a start button.
class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 250),

            // App icon
            Image.asset(
              'assets/AppIcon/Icon.png',
              height: height * 0.20,
              width: width * 0.50,
            ),

            const SizedBox(height: 40),

            // App name
            const Text(
              'Travel Log',
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.w600,
                color: Color(0xff3c3c3c),
                fontFamily: 'Intern',
              ),
            ),

            const SizedBox(height: 10),

            // Tagline text
            Text(
              'Your journey, stored forever',
              style: const TextStyle(
                fontFamily: 'Intern',
                fontWeight: FontWeight.normal,
                fontSize: 20,
                color: Color(0xff1f1f47),
              ),
            ),

            const Spacer(),

            // Start button → navigates to Travel Log Page
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/travelLog');
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.26,
                  vertical: height * 0.02,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: const Color(0xff5d9dff),
              ),
              child: const Text(
                'Start',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Intern',
                ),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
