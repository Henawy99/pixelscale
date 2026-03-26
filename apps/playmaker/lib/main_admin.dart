import 'package:flutter/material.dart';
import 'package:playmakerappstart/config/app_config.dart';
import 'package:playmakerappstart/main.dart' as app;

/// Entry point for Playmaker Admin app
void main() {
  // Set admin flavor before running app
  AppConfig.setFlavor(AppFlavor.admin);
  
  // Run the same app but with admin configuration
  app.main();
}

