import 'package:eset/src/base_ui.dart';
import 'package:eset/src/collections/collection_detail_view.dart';
import 'package:eset/src/gamelist/game_state.dart';

class CollectionsListView extends StatelessWidget {
  const CollectionsListView({super.key});

  static const routeName = '/collections';

  @override
  Widget build(BuildContext context) {
    final store = (GameListStore.ref..watch(context)).of(context);
    final collections = store.collections.entries.toList();
    return ListView.builder(
      itemCount: collections.length,
      itemBuilder: (context, i) {
        final MapEntry(key: collection, value: gamesRomPaths) = collections[i];
        // final games = gamesPaths.map((path) => store.allGames(path)).toList();
        return InkWell(
          onTap: () {
            store.selectCollection(collection);
            Navigator.of(context).pushNamed(CollectionDetailsView.routeName);
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Text('$collection: ${gamesRomPaths.length} games'),
              ],
            ),
          ),
        );
      },
    );
  }
}
