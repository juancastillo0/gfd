import 'package:context_plus/context_plus.dart';
import 'package:eset/src/gamelist/game_model.dart';
import 'package:eset/src/gamelist/game_state.dart';
import 'package:eset/src/system_collection/game_filter_model.dart';
import 'package:eset/src/system_collection/system_model.dart';
import 'package:eset/src/utils/game_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:json_form/json_form.dart';

import '../settings/settings_view.dart';
import 'game_details_view.dart';

/// Displays a list of Games.
class GameListView extends StatelessWidget {
  const GameListView({super.key});

  static const routeName = '/games';

  @override
  Widget build(BuildContext context) {
    final store = (GameListStore.ref..watch(context)).of(context);
    final isBig = MediaQuery.of(context).size.width > 1000;

    final rootFilter = [
      const SizedBox(width: 10),
      if (isBig)
        Text(
          'Filter',
          style: Theme.of(context).textTheme.titleLarge,
        )
      else
        TextButton.icon(
          onPressed: store.toggleFilter,
          label: Text(
            'Filter',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          icon: store.isFiltering
              ? Icon(Icons.filter_alt_off_rounded)
              : Icon(Icons.filter_alt_rounded),
        ),
      Spacer(),
      DropdownMenu(
        controller: store.storedFilterController,
        onSelected: store.selectFilter,
        width: 150,
        dropdownMenuEntries: store.storedFilters.entries
            .map(
              (e) => DropdownMenuEntry(
                value: e.key,
                label: e.key,
              ),
            )
            .toList(),
        // DropdownButtonFormField<String>(
        //   onChanged: store.selectFilter,
        //   items: store.storedFilters.entries
        //       .map(
        //         (e) => DropdownMenuItem(
        //           value: e.key,
        //           child: Text(e.key),
        //         ),
        //       )
        //       .toList(),
        //   value: store.selectedFilter,
        // ),
      ),
    ];

    final filterWidget = SizedBox(
      width: 350,
      child: Column(
        children: [
          Row(
            children: [
              ...rootFilter,
              TextButton(
                onPressed: store.storeFilter,
                child: Text('Store'),
              ),
              Column(
                children: [
                  AnimatedBuilder(
                    animation: store.storedFilterController,
                    builder: (context, child) {
                      return TextButton(
                        onPressed: store.storedFilters
                                .containsKey(store.storedFilterController.text)
                            ? store.deleteFilter
                            : null,
                        child: Text('Delete'),
                      );
                    },
                  ),
                  TextButton(
                    onPressed: store.clearFilter,
                    child: Text('Clear'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: JsonForm(
              controller: store.filterController,
              uiConfig: JsonFormUiConfig(
                submitButtonBuilder: (onSubmit) => SizedBox(),
              ),
              jsonSchema: GameFilter.jsonSchema(
                genres: store.genres,
                systems: store.systems,
                collections: store.collections.keys,
                developers: store.developers,
                publishers: store.publishers,
              ),
              onFormDataSaved: (data) => store.filterGames(),
            ),
          ),
        ],
      ),
    );

    void showCountsDialog() {
      final systemCount = <String, int>{};
      final genreCount = <String, int>{};
      for (final g in store.games) {
        systemCount[g.system] = (systemCount[g.system] ?? 0) + 1;
        genreCount[g.genre ?? ''] = (genreCount[g.genre ?? ''] ?? 0) + 1;
      }
      showDialog(
        context: context,
        builder: (context) {
          final textTheme = Theme.of(context).textTheme;
          return SimpleDialog(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            titlePadding: const EdgeInsets.all(12),
            title: Text(
              'Games Count: ${store.games.length}',
              textAlign: TextAlign.center,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'Systems',
                  style: textTheme.titleLarge,
                ),
              ),
              ...systemCount.entries.map(
                (e) => SimpleDialogOption(
                  onPressed: () {
                    final field =
                        store.filterController.retrieveField('systems')!;
                    field.value = [e.key];
                    Navigator.pop(context);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key),
                      Text(e.value.toString()),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'Genres',
                  style: textTheme.titleLarge,
                ),
              ),
              ...genreCount.entries.map(
                (e) => SimpleDialogOption(
                  onPressed: () {
                    final field =
                        store.filterController.retrieveField('genres')!;
                    field.value = [e.key];
                    Navigator.pop(context);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key == '' ? 'None' : e.key),
                      Text(e.value.toString()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // ),
          );
        },
      );
    }

    final gameListWidget = Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: showCountsDialog,
              icon: Icon(Icons.info_outline_rounded),
              label: Text('${store.games.length} Games'),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              width: 160,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Image Width'),
                      Text('${store.imageWidth.round()}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: store.imageWidth,
                    padding: EdgeInsets.zero,
                    max: 600,
                    min: 40,
                    onChanged: (v) => store.imageWidth = v,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<SystemImageAsset>(
                decoration: InputDecoration(
                  labelText: 'Image',
                ),
                onChanged: store.changeImageAsset,
                items: SystemImageAsset.values
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6.0),
                          child: Text(v.name.replaceFirst(r'$', '')),
                        ),
                      ),
                    )
                    .toList(),
                value: store.imageAssetType,
              ),
            ),
            TextButton.icon(
              onPressed: store.isGridView ? null : store.toggleListGridView,
              icon: Icon(Icons.grid_view),
              label: Text('Grid'),
            ),
            TextButton.icon(
              onPressed: store.isGridView ? store.toggleListGridView : null,
              icon: Icon(Icons.list),
              label: Text('List'),
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: FocusScope(child: _GameList(store: store)),
          ),
        ),
      ],
    );

    final Widget body;
    if (isBig) {
      body = Row(
        children: [
          filterWidget,
          Expanded(child: gameListWidget),
        ],
      );
    } else {
      body = store.isFiltering ? filterWidget : gameListWidget;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Games'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.restorablePushNamed(context, SettingsView.routeName);
            },
          ),
        ],
      ),
      body: body,
    );
  }
}

class _GameList extends StatelessWidget {
  const _GameList({
    required this.store,
  });

  final GameListStore store;

  @override
  Widget build(BuildContext context) {
    final items = store.games;

    VoidCallback onTap(Game item) => () {
          store.selectedGamePath = item.path;
          // Navigate to the details page. If the user leaves and returns to
          // the app after it has been killed while running in the
          // background, the navigation stack is restored.
          Navigator.restorablePushNamed(
            context,
            GameDetailsView.routeName,
          );
        };

    final double imageWidth = store.imageWidth;
    final double extensionWith = 40;
    final double systemWidth = 60;
    final double ratingWidth = 50;
    final double releaseWidth = 75;
    final double genreWidth = 120;
    final double playersWidth = 50;

    List<Widget> otherProps(Game item) => [
          SizedBox(
            width: systemWidth,
            child: Text(item.system),
          ),
          SizedBox(
            width: ratingWidth,
            child: Center(
              child: Text(
                item.rating == null
                    ? ''
                    : (item.rating! * 10).round().toString(),
              ),
            ),
          ),
          SizedBox(
            width: releaseWidth,
            child: Text(
              item.releasedate == null
                  ? ''
                  : '${item.releasedate!.year}-${item.releasedate!.month}',
            ),
          ),
          SizedBox(
            width: genreWidth,
            child: Text(item.genre ?? ''),
          ),
          SizedBox(
            width: playersWidth,
            child: Text(
              (item.playersMax ?? item.playersMin)?.toString() ?? '',
            ),
          ),
        ];

    if (store.isGridView) {
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: imageWidth * 2,
          childAspectRatio: 0.7,
        ),
        // gridDelegate:
        //     SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
        restorationId: 'GameGridView',
        itemCount: items.length,
        itemBuilder: (BuildContext context, int index) {
          final item = items[index];
          return InkWell(
            key: Key(item.path),
            onTap: onTap(item),
            child: Column(
              children: [
                Expanded(
                  child: GameImage(game: item),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    item.relativePath,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                GameDataView(game: item, isSmall: true),
                // Wrap(children: otherProps(item)),
              ],
            ),
          );
        },
      );
    }

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: imageWidth,
              child: Text('Image'),
            ),
            Expanded(
              child: Text('Name'),
            ),
            SizedBox(
              width: extensionWith,
              child: Text('Ext'),
            ),
            SizedBox(
              width: systemWidth,
              child: Text('System'),
            ),
            SizedBox(
              width: ratingWidth,
              child: Text('Rating'),
            ),
            SizedBox(
              width: releaseWidth,
              child: Text('Release'),
            ),
            SizedBox(
              width: genreWidth,
              child: Text('Genre'),
            ),
            SizedBox(
              width: playersWidth,
              child: Text('Players'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            // Providing a restorationId allows the ListView to restore the
            // scroll position when a user leaves and returns to the app after it
            // has been killed while running in the background.
            restorationId: 'GameListView',
            itemCount: items.length,
            itemBuilder: (BuildContext context, int index) {
              final item = items[index];
              return InkWell(
                key: Key(item.path),
                onTap: onTap(item),
                child: Row(
                  children: [
                    SizedBox(
                      width: imageWidth,
                      child: GameImage(width: imageWidth, game: item),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(item.filename),
                      ),
                    ),
                    SizedBox(
                      width: extensionWith,
                      child: Text(item.extension),
                    ),
                    ...otherProps(item),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
