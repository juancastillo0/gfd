import 'dart:convert';
import 'dart:typed_data';

import 'package:eset/src/gamelist/game_model.dart';
import 'package:eset/src/utils/byte_utils.dart';

Map<String, String> parseIdAndNameDB(Uint8List bytes) {
  final Map<String, String> result = {};
  final p = ByteParser(bytes);
  final idStart = Uint8List.fromList([...ascii.encode("_id"), 0]);
  final nameStart = Uint8List.fromList([2, ...ascii.encode("Name")]);
  while (p.offset < bytes.length) {
    try {
      p.takeUntilBytes(idStart);
    } catch (_) {
      break;
    }
    final id =
        base64.encode(p.takeUntilBytes(nameStart)); // p.takeUntil(STX"Name");
    p.takeWhile((b) => !ByteUtils.isAlphanumeric(b));
    final name = utf8.decode(p.takeWhile((b) => b != 0));
    result[id] = name;
  }
  return result;
}

List<Game> parsePlayniteDb(
  Uint8List bytes, {
  Uint8List? companies,
  Uint8List? genres,
  Map<String, List<String>>? gameToAssets,
}) {
  final Map<String, String> genreNames =
      genres != null ? parseIdAndNameDB(genres) : const {};
  final Map<String, String> companyNames =
      companies != null ? parseIdAndNameDB(companies) : const {};
  final result = <Game>[];
  final p = ByteParser(bytes);
  final genreNamesKeyLength =
      genreNames.isEmpty ? 0 : base64.decode(genreNames.keys.first).length;
  final companyNamesKeyLength =
      companyNames.isEmpty ? 0 : base64.decode(companyNames.keys.first).length;
  final idStart = Uint8List.fromList([...ascii.encode("_id"), 0]);
  while (p.offset < bytes.length) {
    try {
      p.takeUntilBytes(idStart);
    } catch (_) {
      break;
    }
    p.takeUntil("Image");
    final prefixAndId = p.takeUntil("\\");
    final s = ByteUtils.splitBytes(prefixAndId, 0);
    final id = ascii.decode(s.last);
    p.takeUntil("Description");
    final descSplit = ByteUtils.splitBytes(p.takeUntil("GenreIds"), 0);
    final desc = utf8.decode(descSplit[descSplit.length - 2]);

    p.take(8);
    // p.takeUntilBytes(Uint8List.fromList(const [5]))
    final genreValue = base64.encode(p.take(genreNamesKeyLength));
    final genreName = genreNames.isEmpty ? null : genreNames[genreValue];
    p.takeUntil("Hidden");
    final isHidden = p.view()[1] == 1;
    p.takeUntil("Favorite");
    final isFavorite = p.view()[1] == 1;

    p.takeUntil("PublisherIds");
    p.take(8);
    final publisherName =
        companyNames[base64.encode(p.take(companyNamesKeyLength))];
    p.takeUntil("DeveloperIds");
    p.take(8);
    final developerName =
        companyNames[base64.encode(p.take(companyNamesKeyLength))];
    p.takeUntil("ReleaseDate");
    final dateSplit = ByteUtils.splitBytes(p.takeUntil("FeatureIds"), 0);
    final date = DateTime.tryParse(
      ascii.decode(dateSplit[dateSplit.length - 2]),
    );

    p.takeUntil("IsInstalled");
    // p.tag("IsInstalled");
    final isInstalled = p.view()[1] == 1;

    p.takeUntil("CommunityScore");
    final communityScore = p.view()[1];

    p.takeUntil("InstallSizeGroup");
    p.takeUntil("Name");
    // p.take(4);
    p.takeWhile((b) => !ByteUtils.isAlphanumeric(b));
    final nameBytes = p.takeWhile((b) => b != 0);
    final name = ascii.decode(nameBytes);
    result.add(Game(
      system: 'pc',
      name: name,
      path: id,
      playniteAssets: gameToAssets?[id] ?? const [],
      desc: desc,
      developer: developerName,
      genre: genreName,
      playersMax: null,
      playersMin: null,
      publisher: publisherName,
      rating: communityScore / 100,
      releasedate: date,
      playniteBooleans: PlayniteBooleans(
        isFavorite: isFavorite,
        isHidden: isHidden,
        isInstalled: isInstalled,
      ),
    ));
  }
  return result;
}

class PlayniteBooleans {
  final bool isHidden;
  final bool isFavorite;
  final bool isInstalled;

  PlayniteBooleans({
    required this.isHidden,
    required this.isFavorite,
    required this.isInstalled,
  });

  Map<String, Object?> toJson() {
    return {
      'isHidden': isHidden,
      'isFavorite': isFavorite,
      'isInstalled': isInstalled,
    };
  }

  @override
  String toString() {
    return toJson().toString();
  }
}
