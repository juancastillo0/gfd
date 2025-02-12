import 'package:eset/src/base_ui.dart';
import 'package:eset/src/gamelist/game_state.dart';

import 'settings_controller.dart';

/// Displays the various settings that can be customized by the user.
///
/// When a user changes a setting, the SettingsController is updated and
/// Widgets that listen to the SettingsController are rebuilt.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key, required this.controller});

  static const routeName = '/settings';

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final gameStore = GameListStore.ref.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        // Glue the SettingsController to the theme selection DropdownButton.
        //
        // When a user selects a theme from the dropdown list, the
        // SettingsController is updated, which rebuilds the MaterialApp.
        child: Column(
          children: [
            DropdownButton<ThemeMode>(
              // Read the selected themeMode from the controller
              value: controller.themeMode,
              // Call the updateThemeMode method any time the user selects a theme.
              onChanged: controller.updateThemeMode,
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System Theme'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text('Light Theme'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text('Dark Theme'),
                )
              ],
            ),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'ES-DE App Data Path',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.folder),
                  onPressed: () {
                    gameStore.selectDirectory(
                      gameStore.paths.esDeAppDataConfigPath,
                    );
                  },
                ),
              ),
              controller: gameStore.esDeAppDataConfigPath,
            ),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Downloaded Media Path',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.folder),
                  onPressed: () {
                    gameStore.selectDirectory(
                      gameStore.paths.downloadedMediaPath,
                    );
                  },
                ),
              ),
              controller: gameStore.downloadedMediaPath,
            ),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Playnite Library Path',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.folder),
                  onPressed: () {
                    gameStore.selectDirectory(
                      gameStore.paths.playniteLibraryPath,
                    );
                  },
                ),
              ),
              controller: gameStore.playniteLibraryPath,
            ),
          ],
        ),
      ),
    );
  }
}
