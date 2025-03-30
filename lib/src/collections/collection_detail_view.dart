import 'package:gfd/src/base_ui.dart';
import 'package:gfd/src/gamelist/game_details_view.dart';
import 'package:gfd/src/gamelist/game_state.dart';

class CollectionDetailsView extends StatelessWidget {
  const CollectionDetailsView({super.key});

  static const routeName = '/collection';

  @override
  Widget build(BuildContext context) {
    final store = (GameListStore.ref..watch(context)).of(context);
    final collection = store.selectedCollection!;
    final gamesRomPaths = store.collections[collection]!;
    final games =
        store.allGames.where((g) => gamesRomPaths.contains(g.romPath)).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection Details'),
      ),
      body: Column(
        children: [
          Text(
            collection,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: games.length,
              itemBuilder: (context, i) {
                final game = games[i];
                return InkWell(
                  onTap: () {
                    store.selectedGamePath = game.path;
                    Navigator.of(context).pushNamed(GameDetailsView.routeName);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(game.path),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
