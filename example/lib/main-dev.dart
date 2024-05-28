import 'package:flutter/cupertino.dart';

import 'app.dart';
import 'core/config/config_manager.dart';
import 'core/config/flavor.dart';

void main() {
  runApp(ConfigManager(
    apiBaseUrl: "dev_api_base_url",
    flavor: Flavor.dev,
    child: App(),
  ));
}
