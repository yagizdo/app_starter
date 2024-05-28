import 'package:flutter/material.dart';

import 'core/config/config_manager.dart';

class TemplateHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Hello from Flappy Template"),
            Text(ConfigManager.of(context)?.apiBaseUrl ?? "No API Base URL"),
          ],
        ),
      ),
    );
  }
}
