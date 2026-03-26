#!/bin/bash

# Quick run script for Al Baseet App
# This runs the app in debug mode on a connected device

cd "$(dirname "$0")"

echo "🏀 Starting Al Baseet Sports App..."
echo ""

flutter run -t lib/main_albaseet.dart
