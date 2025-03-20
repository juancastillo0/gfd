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
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 600,
          ),
          padding: const EdgeInsets.all(16),
          // Glue the SettingsController to the theme selection DropdownButton.
          //
          // When a user selects a theme from the dropdown list, the
          // SettingsController is updated, which rebuilds the MaterialApp.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 10,
            children: [
              DropdownButton<ThemeMode>(
                // Read the selected themeMode from the controller
                value: controller.themeMode,
                // Call the updateThemeMode method any time the user selects a theme.
                onChanged: controller.updateThemeMode,
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: TextNoSelect('System Theme'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: TextNoSelect('Light Theme'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: TextNoSelect('Dark Theme'),
                  )
                ],
              ),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'ES-DE App Data Path',
                  helperText:
                      'Path to the ES-DE App Data folder with the "gamelist" and "collections" folders.'
                      ' If this has the "downloaded_media" folder we will use it as the Downloaded Media Path.',
                  helperMaxLines: 5,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.folder),
                    tooltip: 'Select the ES-DE App Data Folder',
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
                  labelText: 'ES-DE Downloaded Media Path',
                  helperText:
                      'Path to the ES-DE "downloaded_media" folder with assets such as images, videos and manuals.',
                  helperMaxLines: 5,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.folder),
                    tooltip: 'Select the Downloaded Media Folder',
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
                  helperText:
                      'Path to the Playnite Library folder which contains the "games.db",'
                      ' "companies.db" and "genres.db" files along with the "files" folder'
                      ' with assets such as icons, covers and background images.',
                  helperMaxLines: 5,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.folder),
                    tooltip: 'Select the Playnite Library Folder',
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
      ),
    );
  }
}
