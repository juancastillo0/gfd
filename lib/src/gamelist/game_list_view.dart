import 'package:gfd/src/base_ui.dart';
import 'package:gfd/src/gamelist/game_model.dart';
import 'package:gfd/src/gamelist/game_state.dart';
import 'package:gfd/src/system_collection/game_filter_model.dart';
import 'package:gfd/src/system_collection/system_model.dart';
import 'package:gfd/src/utils/game_image_widget.dart';
import 'package:json_form/json_form.dart';
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
      Text(
        'Filter',
        style: Theme.of(context).textTheme.titleLarge,
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

    final filterWidget = Column(
      children: [
        Row(
          children: [
            ...rootFilter,
            Column(
              children: [
                TextButton(
                  onPressed: store.storeFilter,
                  child: TextNoSelect('Store'),
                ),
                AnimatedBuilder(
                  animation: store.storedFilterController,
                  builder: (context, child) {
                    return TextButton(
                      onPressed: store.storedFilters
                              .containsKey(store.storedFilterController.text)
                          ? store.deleteFilter
                          : null,
                      child: TextNoSelect('Delete'),
                    );
                  },
                )
              ],
            ),
            Column(
              children: [
                TextButton(
                  onPressed: store.toggleFilter,
                  child: TextNoSelect('Hide'),
                ),
                TextButton(
                  onPressed: store.clearFilter,
                  child: TextNoSelect('Clear'),
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
              submitButtonBuilder: (onSubmit) => const SizedBox(),
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
    );

    void showCountsDialog() {
      final systemCount = <String, int>{};
      final genreCount = <String, int>{};
      final extensionCount = <String, int>{};
      for (final g in store.games) {
        systemCount[g.system] = (systemCount[g.system] ?? 0) + 1;
        genreCount[g.genre ?? ''] = (genreCount[g.genre ?? ''] ?? 0) + 1;
        extensionCount[g.extension] = (extensionCount[g.extension] ?? 0) + 1;
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
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'Extensions',
                  style: textTheme.titleLarge,
                ),
              ),
              ...extensionCount.entries.map(
                (e) => SimpleDialogOption(
                  // TODO: filter by extension
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key == '' ? 'None' : e.key),
                      Text(e.value.toString()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            // ),
          );
        },
      );
    }

    void gameSelectionMenu(SelectedGamesAction action) {
      switch (action) {
        case SelectedGamesAction.addToCollection:
        case SelectedGamesAction.removeFromCollection:
          showDialog(
            context: context,
            builder: (context) => SimpleDialog(
              title: Text('Select Collection'),
              children: [
                ...store.collections.keys.map(
                  (c) => SimpleDialogOption(
                    onPressed: () {
                      store.updateSelectedGamesCollection(
                        collection: c,
                        add: action == SelectedGamesAction.addToCollection,
                      );
                    },
                    child: Text(c),
                  ),
                )
              ],
            ),
          );
          break;
        case SelectedGamesAction.changeFileExtension:
          showDialog(
            context: context,
            builder: (context) {
              String extension = '';
              return AlertDialog(
                content: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Extension',
                  ),
                  onChanged: (value) => extension = value,
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: TextNoSelect('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      if (extension.isEmpty) return;
                      store.renameSelectedGamesExtension(extension);
                      Navigator.pop(context);
                    },
                    child: TextNoSelect('Rename'),
                  ),
                ],
              );
            },
          );
          break;

        case SelectedGamesAction.selectAll:
        case SelectedGamesAction.clearSelection:
        case SelectedGamesAction.invertSelection:
          store.updateSelectedGames(action);
          break;
      }
    }

    final gameListWidget = Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!store.isFiltering)
              TextButton.icon(
                onPressed: store.toggleFilter,
                icon: Icon(Icons.filter_alt_rounded),
                label: TextNoSelect('Filter'),
              ),
            TextButton.icon(
              onPressed: showCountsDialog,
              icon: Icon(Icons.bar_chart),
              label: TextNoSelect('${store.games.length} Games'),
            ),
            Column(
              children: [
                Tooltip(
                  message: store.isSelectingGames
                      ? 'Cancel Selection'
                      : 'Select Games',
                  child: TextButton.icon(
                    onPressed: store.toggleSelectingGames,
                    icon: store.isSelectingGames
                        ? Icon(Icons.cancel_outlined)
                        : Icon(Icons.checklist_rounded),
                    label: store.isSelectingGames
                        ? TextNoSelect('${store.selectedGames.length} Selected')
                        : TextNoSelect('Select'),
                  ),
                ),
                if (store.isSelectingGames)
                  PopupMenuButton<SelectedGamesAction>(
                    itemBuilder: (context) => SelectedGamesAction.values
                        .map(
                          (a) => PopupMenuItem(
                            value: a,
                            enabled: store.selectedGames.isNotEmpty
                                ? true
                                : !const [
                                    SelectedGamesAction.addToCollection,
                                    SelectedGamesAction.removeFromCollection,
                                    SelectedGamesAction.changeFileExtension,
                                    SelectedGamesAction.clearSelection,
                                  ].contains(a),
                            child: Row(
                              children: [
                                Icon(
                                  const {
                                    SelectedGamesAction.addToCollection:
                                        Icons.add,
                                    SelectedGamesAction.removeFromCollection:
                                        Icons.remove,
                                    SelectedGamesAction.changeFileExtension:
                                        Icons.edit,
                                    SelectedGamesAction.selectAll:
                                        Icons.check_box,
                                    SelectedGamesAction.clearSelection:
                                        Icons.clear,
                                    SelectedGamesAction.invertSelection:
                                        Icons.swap_vert,
                                  }[a],
                                ),
                                const SizedBox(width: 8),
                                TextNoSelect(
                                  a.name.replaceAllMapped(
                                    RegExp('[a-z][A-Z]|^[a-z]'),
                                    (a) => a.group(0)!.length == 1
                                        ? a.group(0)!.toUpperCase()
                                        : '${a.group(0)!.substring(0, 1)} ${a.group(0)!.substring(1)}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onSelected: gameSelectionMenu,
                    tooltip: 'Selection Actions',
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                      child: Row(
                        children: [
                          Icon(Icons.more_horiz),
                          const SizedBox(width: 10),
                          TextNoSelect('Actions'),
                        ],
                      ),
                    ),
                  ),
              ],
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
                      Text(
                        '${store.imageWidth.round() * (store.isGridView ? 2 : 1)}',
                      ),
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
                          child: TextNoSelect(v.name.replaceFirst(r'$', '')),
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
              label: TextNoSelect('Grid'),
            ),
            TextButton.icon(
              onPressed: store.isGridView ? store.toggleListGridView : null,
              icon: Icon(Icons.list),
              label: TextNoSelect('List'),
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
          if (store.isFiltering)
            SizedBox(
              key: Key('filter'),
              width: 370,
              child: filterWidget,
            ),
          Expanded(key: Key('gameList'), child: gameListWidget),
        ],
      );
    } else {
      body = store.isFiltering ? filterWidget : gameListWidget;
    }

    return body;
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
    if (items.isEmpty) {
      final update = store.filterController.lastEvent;
      String updateString = '';
      if (update != null) {
        updateString =
            '\nLast Filter Update for "${update.field.idKey}": ${update.newValue}';
      }
      return Center(
        child: Text(
          'No games found.$updateString',
          textAlign: TextAlign.center,
        ),
      );
    }

    VoidCallback onTap(Game item) => () {
          if (store.controlPressed ||
              store.shiftPressed ||
              store.isSelectingGames) {
            store.selectGame(item);
            return;
          }
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
    final double ratingWidth = 75;
    final double releaseWidth = 85;
    final double genreWidth = 120;
    final double playersWidth = 60;

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
            child: Text(item.playersString),
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
          return Container(
            color: store.selectedGames.contains(item)
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : null,
            child: InkWell(
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
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GameDataView(game: item, isSmall: true),
                  ),
                  // Wrap(children: otherProps(item)),
                ],
              ),
            ),
          );
        },
      );
    }

    final currentOrder =
        store.filterController.retrieveField('order')!.value as List;
    Widget buildOrderableColumn(
      GameOrderKind orderKind,
      Widget title, {
      double? width,
    }) {
      final index = currentOrder
          .indexWhere((e) => e is Map && e['kind'] == orderKind.name);
      final isDesc = index == -1 ? null : currentOrder[index]['isDesc'] == true;
      return InkWell(
        onTap: () => store.orderBy(orderKind),
        child: SizedBox(
          width: width,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              title,
              if (isDesc != null) ...[
                const SizedBox(width: 4),
                Icon(
                  isDesc ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
                TextNoSelect(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              ]
            ],
          ),
        ),
      );
    }

    Widget buildColumn(String title, double width) => Container(
          alignment: Alignment.center,
          width: width,
          child: TextNoSelect(title),
        );

    return Column(
      children: [
        SizedBox(
          height: 30,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildColumn('Image', imageWidth),
              Expanded(
                child: buildOrderableColumn(
                  GameOrderKind.name,
                  SizedBox(
                    child: TextNoSelect('Name'),
                  ),
                ),
              ),
              buildColumn('Ext', extensionWith),
              buildColumn('System', systemWidth),
              buildOrderableColumn(
                GameOrderKind.rating,
                TextNoSelect('Rating'),
                width: ratingWidth,
              ),
              buildOrderableColumn(
                GameOrderKind.date,
                TextNoSelect('Release'),
                width: releaseWidth,
              ),
              buildColumn('Genre', genreWidth),
              buildColumn('Players', playersWidth),
            ],
          ),
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
              return Container(
                color: store.selectedGames.contains(item)
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1)
                    : null,
                child: InkWell(
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
