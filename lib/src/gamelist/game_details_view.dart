import 'dart:io';

import 'package:eset/src/base_ui.dart';
import 'package:eset/src/gamelist/game_model.dart';
import 'package:eset/src/gamelist/game_state.dart';
import 'package:eset/src/system_collection/system_model.dart';
import 'package:eset/src/utils/string_utils.dart';

/// Displays detailed information about a Game.
class GameDetailsView extends StatelessWidget {
  const GameDetailsView({super.key});

  static const routeName = '/game';

  @override
  Widget build(BuildContext context) {
    final store = GameListStore.ref.of(context);
    final game = store.selectedGame ?? store.allGames.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text(game.path),
              if (game.name != null)
                Text(
                  game.name!,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              if (game.desc != null)
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Text(game.desc!),
                ),
              GameDataView(game: game),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Assets',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Wrap(
                children: SystemImageAsset.values
                    .map(
                      (a) => Column(
                        children: [
                          Text(a.name),
                          SizedBox(
                            width: 300,
                            child: Image.file(
                              File(store.imagePath(game, imageAsset: a)),
                              width: 300,
                              errorBuilder: imageAssetErrorBuilder(
                                store.imagePath(game, imageAsset: a),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StarsRating extends StatelessWidget {
  const StarsRating({super.key, required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final rInt = (rating * 10).round();
    return Row(
      children: List.generate(5, (i) {
        return Icon(
          switch ((i + 1) * 2 - rInt) {
            < 1 => Icons.star_rounded,
            == 1 => Icons.star_half_rounded,
            _ => Icons.star_border_rounded,
          },
          size: 18,
        );
      }),
    );
  }
}

class GameDataView extends StatelessWidget {
  const GameDataView({
    super.key,
    required this.game,
    this.isSmall = false,
  });
  final Game game;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    final data = [
      if (game.rating != null)
        (
          'Rating',
          isSmall
              ? Row(
                  children: [
                    Text((game.rating! * 10).round().toString()),
                    const SizedBox(width: 2),
                    StarsRating(rating: game.rating!),
                  ],
                )
              : StarsRating(rating: game.rating!),
          Icons.reviews_rounded,
        ),
      if (game.releasedate != null)
        (
          'Release Date',
          Text(
            simpleDateFormatter(game.releasedate!),
            // TODO: use a monospace font
            style: TextStyle(fontFamily: "monospace"),
          ),
          Icons.date_range_rounded
        ),
      if (game.developer != null && !isSmall)
        ('Developer', Text(game.developer!), Icons.build_rounded),
      if (game.publisher != null && !isSmall)
        ('Publisher', Text(game.publisher!), Icons.business_rounded),
      if (game.genre != null)
        ('Genre', Text(game.genre!), Icons.category_rounded),
      if (game.playersMin != null)
        (
          'Players',
          Text(game.playersString),
          Icons.group_rounded,
        ),
    ];

    if (isSmall) {
      return Wrap(
        spacing: 18,
        alignment: WrapAlignment.spaceBetween,
        children: data
            .map(
              (v) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(v.$3),
                  const SizedBox(width: 8),
                  v.$2,
                ],
              ),
            )
            .toList(),
      );
    }

    return SizedBox(
      height: 150,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 150,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: data
                  .map((v) => Row(
                        children: [
                          Icon(v.$3),
                          const SizedBox(width: 8),
                          Text(v.$1),
                        ],
                      ))
                  .toList(),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: data.map((v) => v.$2).toList(),
          ),
        ],
      ),
    );
  }
}

Widget Function(BuildContext context, Object error, StackTrace? stackTrace)
    imageAssetErrorBuilder(String imagePath) {
  return (BuildContext context, Object error, StackTrace? stackTrace) => Center(
        child: Text(
          'No image found $imagePath',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
}
