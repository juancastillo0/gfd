import 'package:gfd/src/gamelist/playnite.dart';
import 'package:xml/xml.dart';

/// <game>
///   <path>./Sonic the Hedgehog 3 (E).zip</path>
///   <name>Sonic The Hedgehog 3</name>
///   <desc>Sonic the Hedgehog 3 is the third in the Sonic series of games. As with the previous games, it is a side-scrolling platformer based around speed. The basic game remains the same - players collect rings to earn extra lives, which are also used for protection, and scatter everywhere when Sonic is hurt. Sonic can jump on enemies to defeat them, and Spin Dash by holding down and the jump button, then letting go of down. Dr. Robotnik's Death Egg has crash-landed on Floating Island, so called because it harnesses the power of the Chaos Emeralds to float in the air. Robotnik needs them to repair the Death Egg, so he tells the guardian of Floating Island, Knuckles the Echidna, that Sonic and Tails are there to steal them. With Knuckles tricked and trying to stop the heroes at every turn, will they be able to stop Robotnik in time? New to Sonic 3 are three different types of shields; the Fire Shield (which protects you from fire but disappears if you enter water), the Water Shield (which lets you breathe underwater infinitely), and the Electric Shield (which pulls nearby rings towards you). </desc>
///   <rating>0.8</rating>
///   <releasedate>19940123T000000</releasedate>
///   <developer>Sonic Team</developer>
///   <publisher>SEGA</publisher>
///   <genre>Platform</genre>
///   <players>1-2</players>
/// </game>
class Game {
  final String system;
  final String path;
  final String? name;
  final String? desc;
  final double? rating;
  final DateTime? releasedate;
  final String? developer;
  final String? publisher;
  final String? genre;
  final int? playersMin;
  final int? playersMax;
  final List<String>? playniteAssets;
  final PlayniteBooleans? playniteBooleans;

  Game({
    required this.system,
    required this.path,
    required this.name,
    required this.desc,
    required this.rating,
    required this.releasedate,
    required this.developer,
    required this.publisher,
    required this.genre,
    required this.playersMin,
    required this.playersMax,
    this.playniteAssets,
    this.playniteBooleans,
  });

  String get filename => system == 'pc'
      ? name!
      : path.substring(path.lastIndexOf('/') + 1, path.lastIndexOf('.'));
  String get extension =>
      system == 'pc' ? '' : path.substring(path.lastIndexOf('.') + 1);
  String get relativePath =>
      system == 'pc' ? name! : path.substring(path.indexOf('/') + 1);
  String get romPath =>
      // remove "./" from path
      system == 'pc' ? name! : '%ROMPATH%/$system/${path.substring(2)}';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'system': system,
      'path': path,
      'name': name,
      'desc': desc,
      'rating': rating,
      'releasedate': releasedate,
      'developer': developer,
      'publisher': publisher,
      'genre': genre,
      'playersMin': playersMin,
      'playersMax': playersMax,
    };
  }

  factory Game.fromJson(Map<String, dynamic> map) {
    return Game(
      system: map['system'] as String,
      path: map['path'] as String,
      name: map['name'] != null ? map['name'] as String : null,
      desc: map['desc'] != null ? map['desc'] as String : null,
      rating:
          map['rating'] != null ? double.parse(map['rating'] as String) : null,
      releasedate: map['releasedate'] != null
          ? DateTime.parse(map['releasedate'] as String)
          : null,
      developer: map['developer'] != null ? map['developer'] as String : null,
      publisher: map['publisher'] != null ? map['publisher'] as String : null,
      genre: map['genre'] != null ? map['genre'] as String : null,
      playersMin: map['playersMin'] != null ? map['playersMin'] as int : null,
      playersMax: map['playersMax'] != null ? map['playersMax'] as int : null,
    );
  }

  factory Game.fromXml(XmlElement element, String system) {
    final playersStr = element.getElement('players')?.innerText;
    final players = (playersStr?.endsWith('+') ?? false)
        ? [int.parse(playersStr!.substring(0, playersStr.length - 1)), -1]
        : playersStr?.split('-').map(int.parse).toList();
    return Game(
      system: system,
      path: element.getElement('path')!.innerText,
      name: element.getElement('name')?.innerText,
      desc: element.getElement('desc')?.innerText,
      rating: double.tryParse(element.getElement('rating')?.innerText ?? ''),
      releasedate: element.getElement('releasedate') != null
          ? DateTime.parse(element.getElement('releasedate')!.innerText)
          : null,
      developer: element.getElement('developer')?.innerText,
      publisher: element.getElement('publisher')?.innerText,
      genre: element.getElement('genre')?.innerText,
      playersMin: players?.firstOrNull,
      playersMax: players != null && players.length > 1 ? players.last : null,
    );
  }

  String get playersString =>
      '$playersMin${playersMax == null || playersMax == -1 ? '' : '-$playersMax'}';
}
