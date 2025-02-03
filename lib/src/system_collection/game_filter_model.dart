import 'package:eset/src/gamelist/game_model.dart';

class GameFilter {
  final List<String> systems;
  final List<String> genres;
  final List<String> collections;
  final String name;
  final String description;
  final int minRating;
  final DateTime? minDate;
  final DateTime? maxDate;
  final String developer;
  final String publisher;
  final int? minPlayers;
  final int? maxPlayers;
  final List<GameOrder> order;

  GameFilter({
    required this.systems,
    required this.genres,
    required this.collections,
    required this.name,
    required this.description,
    required this.minRating,
    required this.minDate,
    required this.maxDate,
    required this.developer,
    required this.publisher,
    required this.minPlayers,
    required this.maxPlayers,
    required this.order,
  });

  static String jsonSchema({
    required Iterable<String> genres,
    required Iterable<String> systems,
    required Iterable<String> collections,
  }) =>
      // TODO: rating range "maximum": 11 https://github.com/juancastillo0/json_form/issues/15
      '''
{
  "type": "object",
  "properties": {
    "systems": {"type": "array", "uniqueItems": true, "ui:options": {"orderable": false, "copyable": false},
      "items": {"type": "string", "enum": [${systems.map((g) => '"$g"').join(',')}]}},
    "genres": {"type": "array", "uniqueItems": true, "ui:options": {"orderable": false, "copyable": false},
      "items": {"type": "string", "enum": [${genres.map((g) => '"$g"').join(',')}]}},
    "collections": {"type": "array", "uniqueItems": true, "ui:options": {"orderable": false, "copyable": false},
      "items": {"type": "string", "enum": [${collections.map((g) => '"$g"').join(',')}]}},
    "name": {"type": "string"},
    "description": {"type": "string"},
    "minRating": {"type": "integer", "minimum": 1, "maximum": 11, "ui:options": {"widget": "range"}},
    "minDate": {"type": "string", "format": "date"},
    "maxDate": {"type": "string", "format": "date"},
    "developer": {"type": "string", "format": "regex"},
    "publisher": {"type": "string", "format": "regex"},
    "minPlayers": {"type": "integer", "minimum": 1},
    "maxPlayers": {"type": "integer", "minimum": 1},
    "order": {"type": "array", "ui:options": {"copyable": false}, "items": {
      "type": "object", "properties": {
        "kind": {"type": "string", "enum": ["name", "date", "rating"]},
        "isDesc": {"type": "boolean"}
        }
      }
    }
  }
}
''';

  factory GameFilter.fromJson(Map json) {
    return GameFilter(
      systems: (json['systems'] as List).cast(),
      genres: (json['genres'] as List).cast(),
      collections: (json['collections'] as List).cast(),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      minRating: json['minRating'] ?? 1,
      minDate: json['minDate'],
      maxDate: json['maxDate'],
      developer: json['developer'] ?? '',
      publisher: json['publisher'] ?? '',
      minPlayers: json['minPlayers'],
      maxPlayers: json['maxPlayers'],
      order: (json['order'] as List)
          .map((o) => GameOrder.fromJson(o as Map))
          .toList(),
    );
  }

  bool applies(Game g, List<String> gameCollections) {
    return (systems.isEmpty || systems.contains(g.system)) &&
        (genres.isEmpty || genres.contains(g.genre)) &&
        (collections.isEmpty || collections.any(gameCollections.contains)) &&
        (name.isEmpty ||
            (g.name?.toLowerCase().contains(name.toLowerCase()) ?? false)) &&
        (description.isEmpty ||
            (g.desc?.toLowerCase().contains(description.toLowerCase()) ??
                false)) &&
        (g.rating == null || (g.rating! * 10).toInt() >= minRating) &&
        (minDate == null ||
            (g.releasedate == null || minDate!.isBefore(g.releasedate!))) &&
        (maxDate == null ||
            (g.releasedate == null || maxDate!.isAfter(g.releasedate!))) &&
        (developer.isEmpty ||
            g.developer == null ||
            RegExp(developer).hasMatch(g.developer!)) &&
        (publisher.isEmpty ||
            g.publisher == null ||
            RegExp(publisher).hasMatch(g.publisher!));
  }

  Map<String, Object?> toJson() {
    return {
      'systems': [...systems],
      'genres': [...genres],
      'collections': [...collections],
      'name': name,
      'description': description,
      'minDate': minDate,
      'maxDate': maxDate,
      'minPlayers': minPlayers,
      'maxPlayers': maxPlayers,
      'order': order.map((o) => o.toJson()).toList(),
    };
  }
}

class GameOrder {
  final GameOrderKind kind;
  final bool isDesc;

  GameOrder({
    required this.kind,
    required this.isDesc,
  });

  factory GameOrder.fromJson(Map json) {
    return GameOrder(
      kind: GameOrderKind.values.first, // byName(json['kind']),
      isDesc: json['isDesc'],
    );
  }

  Map<String, Object?> toJson() {
    return {
      'kind': kind.name,
      'isDesc': isDesc,
    };
  }
}

enum GameOrderKind {
  name,
  date,
  rating,
}
