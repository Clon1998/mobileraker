// lib/main.dart
import 'package:flutter/material.dart';

/// Minimal, watch-friendly "Hello World".
/// - Uses a dark background and white text for readability on most watch faces.
/// - Uses MediaQuery padding to avoid bezel / system insets on round screens.
/// - Keeps font sizes conservative so text doesn't get clipped on small faces.
void main() => runApp(const WearHelloApp());

class WearHelloApp extends StatelessWidget {
  const WearHelloApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Using a dark theme globally keeps colors consistent and makes it easy
    // to change later (e.g., switch to ambient-mode-specific style).
    return MaterialApp(
      title: 'Mobileraker (Wear)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Choose dark so default text/icon colors contrast with a dark background.
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black, // explicit black background
        textTheme: const TextTheme(
          // headline6 is used below; set a comfortable font size for watches.
          titleLarge: TextStyle(fontSize: 18.0, color: Colors.white),
          bodySmall: TextStyle(fontSize: 12.0, color: Colors.white70),
        ),
      ),
      home: const HelloScreen(),
    );
  }
}

class HelloScreen extends StatelessWidget {
  const HelloScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use MediaQuery padding to respect round devices' inset (bezel).
    final padding = MediaQuery.of(context).viewPadding;
    final horizontalInset = (padding.left + padding.right) / 2;
    final textStyle = Theme.of(context).textTheme.titleLarge;

    return Scaffold(
      // Keep the Scaffold simple; black background is set in theme.
      body: Padding(
        // horizontal inset keeps contents away from curved edges.
        padding: EdgeInsets.fromLTRB(
          8.0 + horizontalInset,
          8.0 + padding.top,
          8.0 + horizontalInset,
          8.0 + padding.bottom,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Short, centered headline. Shortening helps on narrow round faces.
              Text(
                'Hello, Mobileraker!',
                style: textStyle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Watch companion running!',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
