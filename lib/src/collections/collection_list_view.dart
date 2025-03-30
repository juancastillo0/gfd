import 'package:gfd/src/base_ui.dart';
import 'package:gfd/src/collections/collection_detail_view.dart';
import 'package:gfd/src/gamelist/game_state.dart';
import 'package:gfd/src/sample_feature/sample_item.dart';
import 'package:gfd/src/utils/file_drop_target.dart';
import 'package:gfd/src/utils/game_image_widget.dart';

import 'package:file_system_access/file_system_access.dart' as fsa;
import 'package:json_form/json_form.dart';

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
        final pathHandle = store.paths.esDeAppDataConfigPath;
        final themePrefix =
            '${pathHandle.controller.text}/themes/canvas-es-de/_inc/systems';
        final themeSystem = store.collectionSystems[collection];
        // final games = gamesPaths.map((path) => store.allGames(path)).toList();
        final imageWidth = 200.0;
        final collectionId = collection.toLowerCase().replaceAll(' ', '-');
        return InkWell(
          onTap: () {
            store.selectCollection(collection);
            Navigator.of(context).pushNamed(CollectionDetailsView.routeName);
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 200,
                  child: Column(
                    children: [
                      Text(
                        '$collection\n${gamesRomPaths.length} games',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              child: const SizedBox(
                                width: 600,
                                child: ThemeSystemForm(),
                              ),
                            ),
                          );
                        },
                        child: TextNoSelect(
                          themeSystem == null ? 'Create System' : 'Edit System',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                FSAImage(
                  path:
                      '$themePrefix/carousel-icons-icons/medium/$collectionId.webp',
                  pathHandle: pathHandle,
                  width: imageWidth,
                ),
                FSAImage(
                  path:
                      '$themePrefix/carousel-icons-art/medium/$collectionId.webp',
                  pathHandle: pathHandle,
                  width: imageWidth,
                ),
                // TODO: ES-DE/themes/canvas-es-de/_inc/systems/carousel-icons-capsule/art/mario.webp
                FSAImage(
                  path:
                      '$themePrefix/carousel-icons-capsule/screenshots/$collectionId.webp',
                  pathHandle: pathHandle,
                  width: imageWidth,
                ),
                FSAImage(
                  path:
                      '$themePrefix/carousel-icons-capsule/art/$collectionId.webp',
                  pathHandle: pathHandle,
                  width: imageWidth,
                ),
// ES-DE/themes/canvas-es-de/_inc/systems/carousel-icons-art/{}/mario.webp
// ES-DE/themes/canvas-es-de/_inc/systems/carousel-icons-icons/{}/mario.webp
              ],
            ),
          ),
        );
      },
    );
  }
}

class ThemeSystemForm extends StatelessWidget {
  const ThemeSystemForm({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final store = (GameListStore.ref..watch(context)).of(context);

    return JsonForm(
      jsonSchema: ThemeSystem.jsonSchema,
      controller: store.themeSystemController,
      onFormDataSaved: (data) {},
      // uiConfig: JsonFormUiConfig(
      //   labelPosition: LabelPosition.input,
      // ),
      uiSchema: '{"ui:globalOptions": {"width": 400}}',
      uiConfig: JsonFormUiConfig(
        addFileButtonBuilder: (onPressed, key) => InkWell(
          onTap: onPressed,
          child: FileDropTarget(
            onDrop: (added) {
              final field = store.themeSystemController.retrieveField(key)!;
              final list = field.value as List? ?? [];
              field.value = <fsa.XFile>[...list, ...added.map((a) => a.file)];
            },
          ),
        ),
      ),
      fieldFilePicker: (field) {
        return () async {
          final files = await fsa.FileSystem.instance
              .showOpenFilePickerWebSafe(fsa.FsOpenOptions(multiple: false));
          return files.map((f) => f.file).toList();
        };
      },
    );
  }
}
