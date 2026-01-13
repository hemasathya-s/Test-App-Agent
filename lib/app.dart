import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'config/router.dart';

class UrbanAgentApp extends StatelessWidget {
  const UrbanAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'UC Agent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
