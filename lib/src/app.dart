import 'package:eset/src/base_ui.dart';
import 'package:eset/src/collections/collection_list_view.dart';
import 'package:eset/src/collections/collection_detail_view.dart';
import 'package:eset/src/gamelist/game_details_view.dart';
import 'package:eset/src/gamelist/game_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'sample_feature/sample_item_details_view.dart';
import 'sample_feature/sample_item_list_view.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_view.dart';

/// The Widget that configures your application.
class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.settingsController,
  });

  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    final appBarTheme = const AppBarTheme(
      toolbarHeight: 42,
    );
    final inputDecorationTheme = InputDecorationTheme(
      border: const UnderlineInputBorder(),
      filled: true,
      fillColor: Colors.grey.withValues(alpha: 0.1),
    );
    // Glue the SettingsController to the MaterialApp.
    //
    // The ListenableBuilder Widget listens to the SettingsController for changes.
    // Whenever the user updates their settings, the MaterialApp is rebuilt.
    return ListenableBuilder(
      listenable: settingsController,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          // Providing a restorationScopeId allows the Navigator built by the
          // MaterialApp to restore the navigation stack when a user leaves and
          // returns to the app after it has been killed while running in the
          // background.
          restorationScopeId: 'app',
          debugShowCheckedModeBanner: false,
          // Provide the generated AppLocalizations to the MaterialApp. This
          // allows descendant Widgets to display the correct translations
          // depending on the user's locale.
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''), // English, no country code
          ],

          // Use AppLocalizations to configure the correct application title
          // depending on the user's locale.
          //
          // The appTitle is defined in .arb files found in the localization
          // directory.
          onGenerateTitle: (BuildContext context) =>
              AppLocalizations.of(context)!.appTitle,

          // Define a light and dark color theme. Then, read the user's
          // preferred ThemeMode (light, dark, or system default) from the
          // SettingsController to display the correct theme.
          theme: ThemeData(
            useMaterial3: true,
            appBarTheme: appBarTheme,
            inputDecorationTheme: inputDecorationTheme,
            colorScheme: ColorScheme.light(
              primary: Colors.blueAccent,
              surfaceContainerHighest: Colors.blueAccent.withValues(alpha: 0.1),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            appBarTheme: appBarTheme,
            inputDecorationTheme: inputDecorationTheme,
            colorScheme: ColorScheme.dark(
              primary: Colors.blueAccent,
              surfaceContainerHighest: Colors.blueAccent.withValues(alpha: 0.1),
              onSurface: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          themeMode: settingsController.themeMode,

          // Define a function to handle named routes in order to support
          // Flutter web url navigation and deep linking.
          onGenerateRoute: (RouteSettings routeSettings) {
            return MaterialPageRoute<void>(
              settings: routeSettings,
              builder: (BuildContext context) {
                switch (routeSettings.name) {
                  case SettingsView.routeName:
                    return SettingsView(controller: settingsController);
                  case SampleItemDetailsView.routeName:
                    return const SampleItemDetailsView();
                  case SampleItemListView.routeName:
                    return const SampleItemListView();

                  case CollectionsListView.routeName:
                    return const MainPage(tab: MainTab.collections);
                  case CollectionDetailsView.routeName:
                    return const CollectionDetailsView();
                  case GameDetailsView.routeName:
                    return const GameDetailsView();
                  case GameListView.routeName:
                  default:
                    return const MainPage(tab: MainTab.games);
                }
              },
            );
          },
        );
      },
    );
  }
}
