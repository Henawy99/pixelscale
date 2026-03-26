import 'package:flutter/material.dart';
import 'package:playmakerappstart/config/app_config.dart';
import 'package:playmakerappstart/main.dart' as app;

/// Entry point for Playmaker Partner app (for field owners)
void main() {
  // Set partner flavor before running app
  AppConfig.setFlavor(AppFlavor.partner);
  
  // Run the same app but with partner configuration
  app.main();
}
