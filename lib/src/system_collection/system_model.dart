class GameSystem {
  /// ps2
  final String shortName;

  /// Sony PlayStation 2
  final String fullName;
  final DateTime? releaseDate;
  final bool isCustomCollection;
  // TODO: supported file extensions
  // TODO: theme folder: ps2

  GameSystem({
    required this.shortName,
    required this.releaseDate,
    required this.fullName,
    this.isCustomCollection = false,
  });
}

final gameSystems = [
  GameSystem(
    fullName: 'Sony PlayStation 2',
    shortName: 'ps2',
    releaseDate: DateTime(2000, 3, 4),
  ),
  GameSystem(
    fullName: 'Sega Genesis',
    shortName: 'genesis',
    releaseDate: DateTime(1988, 8, 14),
  ),
];

class SystemAssets {
  // 3dboxes
  // backcovers
  // box2dfront (not in canvas)
  // covers
  // fanart
  // manuals (pdf)
  // marquees
  // miximages
  // physicalmedia
  // screenshots
  // titlescreens
  // videos
  // wheel
}

enum SystemImageAsset {
  $3dboxes,
  backcovers,
  covers,
  marquees,
  miximages,
  physicalmedia,
  screenshots,
  titlescreens,
}
