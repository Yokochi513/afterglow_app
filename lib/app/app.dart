import 'package:afterglow_app/app/dependencies.dart';
import 'package:afterglow_app/ui/auth/auth_gate.dart';
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return DependencyScope(
      dependencies: dependencies,
      child: MaterialApp(
        title: 'Afterglow',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          fontFamily: 'NotoSansJP',
        ),
        home: const AuthGate(),
      ),
    );
  }
}
