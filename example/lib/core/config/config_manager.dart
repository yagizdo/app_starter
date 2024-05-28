import 'package:flutter/cupertino.dart';

import 'flavor.dart';

class ConfigManager extends InheritedWidget {
  ConfigManager({
    Key? key,
    required Widget child,
    required this.apiBaseUrl,
    required this.flavor,
  }) : super(key: key, child: child);

  final String apiBaseUrl;
  final Flavor flavor;

  static ConfigManager? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType(aspect: ConfigManager);
  }

  @override
  bool updateShouldNotify(ConfigManager oldWidget) =>
      oldWidget.apiBaseUrl != apiBaseUrl;
}
