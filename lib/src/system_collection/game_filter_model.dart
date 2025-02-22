import 'package:eset/src/gamelist/game_model.dart';

class GameFilter {
  final List<String> systems;
  final List<String> genres;
  final List<String> collections;
  final List<String> developers;
  final List<String> publishers;
  final String name;
  final String description;
  final int minRating;
  final int maxRating;
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
    required this.developers,
    required this.publishers,
    required this.name,
    required this.description,
    required this.minRating,
    required this.maxRating,
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
    required Iterable<String> developers,
    required Iterable<String> publishers,
  }) =>
      // TODO: rating range "maximum": 11 https://github.com/juancastillo0/json_form/issues/15
      '''
{
  "type": "object",
  "properties": {
    "name": {"type": "string"},
    "description": {"type": "string"},
    "minRating": {"type": "integer", "default": 1,  "minimum": 1, "maximum": 11, "ui:options": {"widget": "range"}},
    "maxRating": {"type": "integer", "default": 10,  "minimum": 1, "maximum": 11, "ui:options": {"widget": "range"}},
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
    },
    "systems": {"type": "array", "uniqueItems": true, "ui:options": {"orderable": false, "copyable": false},
      "items": {"type": "string", "enum": [${systems.map((g) => '"$g"').join(',')}]}},
    "genres": {"type": "array", "uniqueItems": true, "ui:options": {"orderable": false, "copyable": false},
      "items": {"type": "string", "enum": [${genres.map((g) => '"$g"').join(',')}]}},
    "collections": {"type": "array", "uniqueItems": true, "ui:options": {"orderable": false, "copyable": false},
      "items": {"type": "string", "enum": [${collections.map((g) => '"$g"').join(',')}]}},
    "developers": {"type": "array", "uniqueItems": true, "ui:options": {"orderable": false, "copyable": false},
      "items": {"type": "string", "enum": [${developers.map((g) => '"$g"').join(',')}]}},
    "publishers": {"type": "array", "uniqueItems": true, "ui:options": {"orderable": false, "copyable": false},
      "items": {"type": "string", "enum": [${publishers.map((g) => '"$g"').join(',')}]}}
  }
}
''';

  factory GameFilter.fromJson(Map json) {
    return GameFilter(
      systems: (json['systems'] as List?)?.cast() ?? const [],
      genres: (json['genres'] as List?)?.cast() ?? const [],
      collections: (json['collections'] as List?)?.cast() ?? const [],
      developers: (json['developers'] as List?)?.cast() ?? const [],
      publishers: (json['publishers'] as List?)?.cast() ?? const [],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      minRating: json['minRating'] ?? 1,
      maxRating: json['maxRating'] ?? 10,
      minDate: json['minDate'],
      maxDate: json['maxDate'],
      developer: json['developer'] ?? '',
      publisher: json['publisher'] ?? '',
      minPlayers: json['minPlayers'],
      maxPlayers: json['maxPlayers'],
      order: json['order'] == null
          ? const []
          : (json['order'] as List)
              .where((o) => o is Map && o['kind'] is String)
              .map((o) => GameOrder.fromJson(o as Map))
              .toList(),
    );
  }

  bool applies(Game g, List<String> gameCollections) {
    return (systems.isEmpty || systems.contains(g.system)) &&
        (genres.isEmpty || genres.contains(g.genre)) &&
        (collections.isEmpty || collections.any(gameCollections.contains)) &&
        stringMatches(name, g.name) &&
        stringMatches(description, g.desc) &&
        (g.rating == null || (g.rating! * 10).toInt() >= minRating) &&
        (g.rating == null || (g.rating! * 10).toInt() <= maxRating) &&
        (minDate == null ||
            (g.releasedate == null || minDate!.isBefore(g.releasedate!))) &&
        (maxDate == null ||
            (g.releasedate == null || maxDate!.isAfter(g.releasedate!))) &&
        (developer.isNotEmpty && stringMatches(developer, g.developer) ||
            developers.contains(g.developer) ||
            (developers.isEmpty && developer.isEmpty)) &&
        (publisher.isNotEmpty && stringMatches(publisher, g.publisher) ||
            publishers.contains(g.publisher) ||
            (publishers.isEmpty && publisher.isEmpty));
  }

  static bool stringMatches(String pattern, String? value) {
    if (pattern.isEmpty || value == null) return true;
    try {
      final p = RegExp(pattern, caseSensitive: false);
      if (p.hasMatch(value)) return true;
    } catch (_) {}
    final toReplace = RegExp(r'[\s:,_-]+');
    return value.trim().replaceAll(toReplace, ' ').toLowerCase().contains(
          pattern.trim().toLowerCase().replaceAll(toReplace, ' '),
        );
  }

  Map<String, Object?> toJson() {
    return {
      'systems': [...systems],
      'genres': [...genres],
      'collections': [...collections],
      'developers': [...developers],
      'publishers': [...publishers],
      'name': name,
      'description': description,
      'developer': developer,
      'publisher': publisher,
      'minRating': minRating,
      'maxRating': maxRating,
      'minDate': minDate,
      'maxDate': maxDate,
      'minPlayers': minPlayers,
      'maxPlayers': maxPlayers,
      'order': order.map((o) => o.toJson()).toList(),
    };
  }

  int compare(Game a, Game b) {
    for (final orderI in order) {
      final aValue = orderI.kind.extract(a);
      final bValue = orderI.kind.extract(b);
      if (aValue == null && bValue == null) continue;
      if (aValue == null) return orderI.isDesc ? 1 : -1;
      if (bValue == null) return orderI.isDesc ? -1 : 1;
      final compare = aValue.compareTo(bValue);
      if (compare != 0) {
        return orderI.isDesc ? -compare : compare;
      }
    }
    return 0;
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
      kind: GameOrderKind.values.byName(json['kind']), // byName(json['kind']),
      isDesc: json['isDesc'] ?? false,
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
  rating;

  Comparable? extract(Game a) {
    return switch (this) {
      name => a.name,
      date => a.releasedate,
      rating => a.rating,
    };
  }
}
