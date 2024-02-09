import 'package:flutter/material.dart';
import 'package:cinemon/screens/homefeed.dart';
import 'package:cinemon/screens/post.dart';
import 'package:cinemon/screens/profile.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/home', // Set initial route to HomeFeedPage
      routes: {
        '/home': (context) => HomeFeedPage(),
        '/post': (context) => PostPage(),
        '/profile': (context) => ProfilePage(),
      },
      theme: ThemeData(
        brightness: Brightness.dark,
      ),
    );
  }
}
