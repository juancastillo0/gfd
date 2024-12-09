/// A placeholder class that represents an entity or model.
class SampleItem {
  const SampleItem(this.id);

  final int id;
}

class Collection {
  final String name;
  final String icon;
  final GameFilter? filter;

  Collection({
    required this.name,
    required this.icon,
    required this.filter,
  });
}

class GameFilter {}

class CustomSystem {}

class DownloadedMedia {}

class GameLists {}

class EsDeData {
  final List<Collection> collections;
  // final List<Controllers> controllers;
  final List<CustomSystem> customSystems;
  final DownloadedMedia downloadedMedia;
  final GameLists gameLists;
  final EsDeSettings settings;
  final List<EsDeTheme> themes;

  EsDeData({
    required this.collections,
    required this.customSystems,
    required this.downloadedMedia,
    required this.gameLists,
    required this.settings,
    required this.themes,
  });
}

/// ```xml
/// <string name="ROMDirectory" value="F:\Emulation\roms" />
/// <string name="MediaDirectory" value="F:\Emulation/storage/downloaded_media" />
/// <string name="ThemeSet" value="canvas-es-de" />
/// ```
class EsDeSettings {
  final String romDirectory;
  final String mediaDirectory;
  final String themeSet;
  // TODO: /ES-DE/settings/es_input.xml: controller
  // TODO: /ES-DE/settings/es_settingd.xml: scraper, ui, ...

  EsDeSettings({
    required this.romDirectory,
    required this.mediaDirectory,
    required this.themeSet,
  });
}

class EsDeTheme {
  final String wallpaper;
  // Custom collections as systems
  final List<ThemeSystem> systems;
  // F:\games\ES-DE\themes\canvas-es-de\capabilities.xml
  final List<ThemeColorScheme> colorSchemes;
  // F:\games\ES-DE\themes\canvas-es-de\capabilities.xml
  final List<String> variants;

  EsDeTheme({
    required this.wallpaper,
    required this.systems,
    required this.colorSchemes,
    required this.variants,
  });
}

class ThemeColorScheme {}

/// F:\games\ES-DE\themes\canvas-es-de\_inc\systems\metadata-global\mario.xml
class ThemeSystem {
// mario
  final String systemId;
// Super Mario
  final String systemName;
// View and play the Mario Games in your collection.
  final String systemDescription;
// Nintendo
  final String systemManufacturer;
// Various
  final String systemReleaseYear;
// Various
  final String systemReleaseDate;
// Various
  final String systemReleaseDateFormated;
// Various
  final String systemHardwareType;
// 1-1
  final String systemCoverSize;
// 3F549D
  final String systemColor;
// FED01B
  final String systemColorPalette1;
// BA2318
  final String systemColorPalette2;
// 0A2A8D
  final String systemColorPalette3;
// 007544
  final String systemColorPalette4;
// 1-1
  final String systemCartSize;

  ThemeSystem({
    required this.systemId,
    required this.systemName,
    required this.systemDescription,
    required this.systemManufacturer,
    required this.systemReleaseYear,
    required this.systemReleaseDate,
    required this.systemReleaseDateFormated,
    required this.systemHardwareType,
    required this.systemCoverSize,
    required this.systemColor,
    required this.systemColorPalette1,
    required this.systemColorPalette2,
    required this.systemColorPalette3,
    required this.systemColorPalette4,
    required this.systemCartSize,
  });
}
