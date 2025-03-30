import 'package:gfd/src/system_collection/game_filter_model.dart';
import 'package:xml/xml.dart';

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

// class GameFilter {}

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
/// Installation value="C:\Users\user\EmuDeck\EmulationStation-DE\ES-DE" />
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

/// F:\games\ES-DE\themes\canvas-es-de\_inc\systems\metadata-global\gba.xml
/// ```xml
/// <theme>
///    <variables>
///      <systemName>Game Boy Advance</systemName>
///      <systemDescription>The Game Boy Advance (abbreviated as GBA) is a 32-bit handheld video game
///         console developed, manufactured and marketed by Nintendo as the successor to the Game Boy Color.
///         It was released in Japan on March 21, 2001, in North America on June 11, 2001, in Australia and
///         Europe on June 22, 2001, and in mainland China on June 8, 2004 (iQue Player). Nintendo's competitors
///         in the handheld market at the time were the Neo Geo Pocket Color, WonderSwan, GP32, Tapwave Zodiac,
///         and the N-Gage. Despite the competitors' best efforts, Nintendo maintained a majority market
///         share with the Game Boy Advance. As of June 30, 2010, the Game Boy Advance series has sold
///         81.51 million units worldwide. Its successor, the Nintendo DS, was released in November 2004
///         and is also compatible with Game Boy Advance software.
///      </systemDescription>
///      <systemManufacturer>Nintendo</systemManufacturer>
///      <systemReleaseYear>2001</systemReleaseYear>
///      <systemReleaseDate>2001-06-11</systemReleaseDate>
///      <systemReleaseDateFormated>June 11, 2001</systemReleaseDateFormated>
///      <systemHardwareType>Portable</systemHardwareType>
///      <systemCoverSize>1-1</systemCoverSize>
///      <systemColor>4C74D6</systemColor>
///      <systemColorPalette1>5C67A9</systemColorPalette1>
///      <systemColorPalette2>280FBE</systemColorPalette2>
///      <systemColorPalette3>BCBCBC</systemColorPalette3>
///      <systemColorPalette4>212121</systemColorPalette4>
/// 	   <systemCartSize>112-67</systemCartSize>
///   </variables>
/// </theme>
/// ```
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

  static const jsonSchema = r'''
{
  "type": "object",
  "required": [
    "systemId",
    "systemName",
    "systemCoverSize",
    "systemColor",
    "systemColorPalette1",
    "systemColorPalette2",
    "systemColorPalette3",
    "systemColorPalette4",
    "systemCartSize"
  ],
  "properties": {
    "systemId": {"type": "string"},
    "systemName": {"type": "string"},
    "systemName": {"type": "string"},
    "logo": {"type": "string", "format": "data-url"},
    "art": {"type": "string", "format": "data-url"},
    "icon": {"type": "string", "format": "data-url"},
    "systemDescription": {"type": "string"},
    "systemManufacturer": {"type": "string"},
    "systemReleaseDate": {"type": "string", "default": "Various"},
    "systemHardwareType": {"type": "string", "default": "Various"},
    "systemCoverSize": {"type": "string", "default": "1-1"},
    "systemColor": {"type": "string", "pattern": "^[0-9A-Fa-f]{1,6}$"},
    "systemColorPalette1": {"type": "string", "pattern": "^[0-9A-Fa-f]{1,6}$"},
    "systemColorPalette2": {"type": "string", "pattern": "^[0-9A-Fa-f]{1,6}$"},
    "systemColorPalette3": {"type": "string", "pattern": "^[0-9A-Fa-f]{1,6}$"},
    "systemColorPalette4": {"type": "string", "pattern": "^[0-9A-Fa-f]{1,6}$"},
    "systemCartSize": {"type": "string", "default": "1-1"}
  }
}''';

  factory ThemeSystem.fromJson(Map<String, dynamic> map) {
    return ThemeSystem(
      systemId: map['systemId'] as String,
      systemName: map['systemName'] as String,
      systemDescription: map['systemDescription'] as String,
      systemManufacturer: map['systemManufacturer'] as String,
      systemReleaseYear: map['systemReleaseYear'] as String,
      systemReleaseDate: map['systemReleaseDate'] as String,
      systemReleaseDateFormated: map['systemReleaseDateFormated'] as String,
      systemHardwareType: map['systemHardwareType'] as String,
      systemCoverSize: map['systemCoverSize'] as String,
      systemColor: map['systemColor'] as String,
      systemColorPalette1: (map['systemColorPalette1'] as String).toUpperCase(),
      systemColorPalette2: (map['systemColorPalette2'] as String).toUpperCase(),
      systemColorPalette3: (map['systemColorPalette3'] as String).toUpperCase(),
      systemColorPalette4: (map['systemColorPalette4'] as String).toUpperCase(),
      systemCartSize: map['systemCartSize'] as String,
    );
  }

  factory ThemeSystem.fromXml(String systemId, XmlElement element) {
    return ThemeSystem(
      systemId: systemId,
      systemName: element.getElement('systemName')!.innerText,
      systemDescription: element.getElement('systemDescription')!.innerText,
      systemManufacturer: element.getElement('systemManufacturer')!.innerText,
      systemReleaseYear: element.getElement('systemReleaseYear')!.innerText,
      systemReleaseDate: element.getElement('systemReleaseDate')!.innerText,
      systemReleaseDateFormated:
          element.getElement('systemReleaseDateFormated')!.innerText,
      systemHardwareType: element.getElement('systemHardwareType')!.innerText,
      systemCoverSize: element.getElement('systemCoverSize')!.innerText,
      systemColor: element.getElement('systemColor')!.innerText,
      systemColorPalette1: element.getElement('systemColorPalette1')!.innerText,
      systemColorPalette2: element.getElement('systemColorPalette2')!.innerText,
      systemColorPalette3: element.getElement('systemColorPalette3')!.innerText,
      systemColorPalette4: element.getElement('systemColorPalette4')!.innerText,
      systemCartSize: element.getElement('systemCartSize')!.innerText,
    );
  }
}

/// ES-DE/themes/canvas-es-de/mario/theme.xml
/// ```xml
/// <theme>
///   <include>./../theme.xml</include>
/// </theme>
/// ```
/// ES-DE/themes/canvas-es-de/_inc/systems/metadata-global/mario.xml
/// ES-DE/themes/canvas-es-de/_inc/systems/system/mario.svg
class ThemeSystemAssets {
  /// dark, light, medium
  /// ES-DE/themes/canvas-es-de/_inc/systems/carousel-icons-art/{}/mario.webp
  /// 800x1000
  final String art;

  /// art, screenshots
  /// ES-DE/themes/canvas-es-de/_inc/systems/carousel-icons-capsule/{}/mario.webp
  /// art: 1012x1022 or 1040x1039
  /// screenshots: 600x600
  final String capsule;

  /// clear, dark, light, medium
  /// ES-DE/themes/canvas-es-de/_inc/systems/carousel-icons-icons/{}/mario.webp
  /// 800x1000
  final String icons;

  ThemeSystemAssets({
    required this.art,
    required this.capsule,
    required this.icons,
  });
}

class ThemeSystemAssetsComponents {
  final String logo;
  final String art;
  final String icon;

  ThemeSystemAssetsComponents({
    required this.logo,
    required this.art,
    required this.icon,
  });
}
