import 'package:context_plus/context_plus.dart';
import 'package:gfd/src/gamelist/game_state.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';

void main() async {
  // Set up the SettingsController, which will glue user settings to multiple
  // Flutter Widgets.
  final settingsController = SettingsController(SettingsService());

  // Load the user's preferred theme while the splash screen is displayed.
  // This prevents a sudden theme change when the app is first displayed.
  await settingsController.loadSettings();

  // Run the app and pass in the SettingsController. The app listens to the
  // SettingsController for changes, then passes it further down to the
  // SettingsView.
  runApp(ContextPlus.root(child: Builder(builder: (context) {
    GameListStore.ref.bind(context, () => GameListStore());
    return MyApp(settingsController: settingsController);
  })));
}
