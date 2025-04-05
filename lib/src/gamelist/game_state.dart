import 'dart:io' as io;
import 'dart:async';
import 'dart:convert';

import 'package:context_plus/context_plus.dart';
import 'package:gfd/src/base_ui.dart' show TextEditingController;
import 'package:gfd/src/gamelist/game_data.dart';
import 'package:gfd/src/gamelist/game_model.dart';
import 'package:gfd/src/gamelist/playnite.dart';
import 'package:gfd/src/sample_feature/sample_item.dart';
import 'package:gfd/src/system_collection/game_filter_model.dart';
import 'package:gfd/src/system_collection/system_model.dart';
import 'package:flutter/foundation.dart';
import 'package:gfd/src/utils/string_utils.dart';
import 'package:json_form/json_form.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_system_access/file_system_access.dart' as fsa;
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

class GameListStore extends ChangeNotifier {
  GameListStore() {
    _loadState().then((_) => _loadGames());
    if (kIsWeb) {
      fsa.FileSystem.instance.webDropFileEvents();
    }
    filterController = JsonFormController(initialData: {});

    Timer? saveStateTimer;

    ServicesBinding.instance.keyboard.addHandler(_onKey);
    addListener(() {
      saveStateTimer ??= Timer(
        const Duration(seconds: 5),
        () {
          saveState();
          saveStateTimer = null;
        },
      );
    });
  }

  bool shiftPressed = false;
  bool controlPressed = false;

  bool _onKey(KeyEvent event) {
    if ({
      LogicalKeyboardKey.shift,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
    }.contains(event.logicalKey)) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        shiftPressed = true;
      } else if (event is KeyUpEvent) {
        shiftPressed = false;
      }
      notifyListeners();
    } else if ({
      LogicalKeyboardKey.meta,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
    }.contains(event.logicalKey)) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        controlPressed = true;
      } else if (event is KeyUpEvent) {
        controlPressed = false;
      }
      notifyListeners();
    } else if (event is KeyDownEvent && event.character == 'f') {
      if (controlPressed) {
        filterController.retrieveField('name')!.focusNode.requestFocus();
      }
    } else if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.f1) {
      showFilter = !showFilter;
      notifyListeners();
    } else if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.f2) {
      isSelectingGames = !isSelectingGames;
      notifyListeners();
    }

    return false;
  }

  static final ref = Ref<GameListStore>();

  final List<Game> allGames = [];
  List<Game> games = [];
  final _errorsStreamController = StreamController<String>.broadcast();
  Stream<String> get errorsStream => _errorsStreamController.stream;
  final _messagesStreamController = StreamController<String>.broadcast();
  Stream<String> get messagesStream => _messagesStreamController.stream;

  String? selectedCollection;
  String? _selectedGamePath;
  String? get selectedGamePath => _selectedGamePath;
  set selectedGamePath(String? selectedGamePath) {
    _selectedGamePath = selectedGamePath;
    notifyListeners();
  }

  Game? get selectedGame {
    return selectedGamePath == null
        ? null
        : allGames.firstWhere((game) => game.path == selectedGamePath);
  }

  ///
  /// COMPUTED
  ///
  Map<String, List<String>> collections = {};
  Map<String, ThemeSystem> collectionSystems = {};
  Map<String, List<String>> gameToCollection = {};
  Set<String> genres = {};
  Set<String> developers = {};
  Set<String> publishers = {};
  Set<String> systems = {};

  JsonFormController? _filterController;
  JsonFormController get filterController => _filterController!;
  set filterController(JsonFormController v) {
    _filterController?.dispose();
    _filterController = v;
    v.addListener(_onFilterUpdate);
  }

  bool _executeScheduledUpdate = false;
  Timer? _filterUpdateTimer;

  void _onFilterUpdate() {
    if (_filterUpdateTimer != null) {
      _executeScheduledUpdate = true;
    } else {
      void update() {
        if (_filterUpdateTimer == null || _executeScheduledUpdate) {
          final gameFilter =
              GameFilter.fromJson(filterController.rootOutputData as Map);
          _applyFilter(gameFilter);
        }
        _executeScheduledUpdate = false;
        _filterUpdateTimer = null;
      }

      update();
      _filterUpdateTimer = Timer(
        const Duration(milliseconds: 1000),
        update,
      );
    }
  }

  TextEditingController get downloadedMediaPath =>
      paths.downloadedMediaPath.controller;
  TextEditingController get esDeAppDataConfigPath =>
      paths.esDeAppDataConfigPath.controller;
  TextEditingController get playniteLibraryPath =>
      paths.playniteLibraryPath.controller;

  ///
  /// DATA
  ///
  GameListPaths paths = GameListPaths();

  final storedFilterController = TextEditingController();
  Map<String, GameFilter> storedFilters = {};
  bool showFilter = false; // TODO: proper responsive handling
  bool isGridView = false;
  SystemImageAsset imageAssetType = SystemImageAsset.covers;
  bool isFiltering = true;
  double _imageWidth = 120;
  Set<Game> selectedGames = {};
  bool isSelectingGames = false;
  double get imageWidth => _imageWidth;
  set imageWidth(double imageWith) {
    _imageWidth = imageWith;
    notifyListeners();
  }

  static const customCollectionPrefix = 'custom-';

  GameListData toData() {
    return GameListData(
      selectedGamePath: selectedGamePath,
      paths: paths,
      storedFilter: storedFilterController.text,
      storedFilters: storedFilters,
      showFilter: showFilter,
      isGridView: isGridView,
      imageAssetType: imageAssetType,
      isFiltering: isFiltering,
      imageWidth: imageWidth,
    );
  }

  String imagePath(Game item, {SystemImageAsset? imageAsset}) {
    final type = (imageAsset ?? imageAssetType);
    String dirPath = item.system == 'pc'
        ? playniteLibraryPath.text
        : downloadedMediaPath.text;
    if (!endsWithPathSeparator(dirPath)) dirPath = '$dirPath/';

    if (item.system == 'pc') {
      final l = type == SystemImageAsset.screenshots
          ? item.playniteAssets!.reversed
          : item.playniteAssets!;
      final relative = l.firstWhere(
        (element) => type == SystemImageAsset.marquees
            ? !element.endsWith('.jpg')
            : element.endsWith('.jpg'),
        orElse: () => '${item.path}/image.png',
      );
      return '${dirPath}files/$relative';
    }
    final a = type.name.replaceFirst(r'$', '');
    final path = '$dirPath${item.system}/$a/${item.filename}.png';
    return path;
  }

  void changeImageAsset(SystemImageAsset? imageAssetType) {
    if (imageAssetType == null) return;
    this.imageAssetType = imageAssetType;
    notifyListeners();
  }

  static const _sharedPreferenceKey = 'games_store';

  JsonFormController themeSystemController =
      JsonFormController(initialData: {});

  Future<void> renameSelectedGame(String newName) async {
    final game = selectedGame;
    if (game == null) return;
    renameGames({game: newName});
  }

  Future<void> renameSelectedGamesExtension(String extension) async {
    if (extension.isEmpty) return;
    await renameGames(
      Map.fromIterables(
        selectedGames,
        selectedGames.map((g) => '${g.filename}.$extension'),
      ),
    );
  }

  Future<void> renameGames(Map<Game, String> gamesToRename) async {
    if (gamesToRename.keys.any((g) => g.system == 'pc')) {
      return _errorsStreamController.add(
        'Renaming PC games is not supported.',
      );
    }

    /// Validate Names
    if (gamesToRename.isEmpty) return;
    for (final MapEntry(key: gameToRename, :value) in gamesToRename.entries) {
      if (value.isEmpty) {
        return _errorsStreamController.add('A game filename cannot be empty.');
      }
      for (final g in allGames) {
        if (g.system == gameToRename.system && g.filename == value) {
          return _errorsStreamController.add('Duplicate name: "$value".');
        }
      }
    }

    /// Validate Paths and Permissions
    final esDeHandle = paths.esDeAppDataConfigPath.handle;
    if (esDeHandle == null) {
      return _errorsStreamController.add(
        'No ES-DE path configured in settings.'
        ' Required for renaming gamelists and collections.',
      );
    }
    final gamelistsDir =
        (await esDeHandle.getDirectoryHandle('gamelists')).okOrNull;
    if (gamelistsDir == null) {
      return _errorsStreamController.add(
        'No "gamelists" directory in ES-DE path.',
      );
    }
    final pg = await gamelistsDir.requestPermission(
      mode: fsa.FileSystemPermissionMode.readwrite,
    );
    if (pg != fsa.PermissionStateEnum.granted) return;
    final collectionsDir =
        (await esDeHandle.getDirectoryHandle('collections')).okOrNull;
    if (collectionsDir == null) {
      return _errorsStreamController.add(
        'No "collections" directory in ES-DE path.',
      );
    }
    final pc = await collectionsDir.requestPermission(
      mode: fsa.FileSystemPermissionMode.readwrite,
    );
    if (pc != fsa.PermissionStateEnum.granted) return;

    /// Retrieve Files to Edit
    final systems = gamesToRename.keys.map((g) => g.system).toSet();
    final collections = gamesToRename.keys
        .expand((g) => gameToCollection[g.romPath] ?? const <String>[])
        .toSet();

    final gamelistsR = await Future.wait(systems.map(
      (s) => gamelistsDir.getNestedFileHandle('$s/gamelist.xml'),
    ));
    final gamelists = gamelistsR
        .map((g) => g.okOrNull)
        .whereType<fsa.FileSystemFileHandle>()
        .toList();
    if (gamelists.length != systems.length) return;

    final collectionListR = await Future.wait(collections.map(
      (collection) => collectionsDir
          .getFileHandle('$customCollectionPrefix$collection.cfg'),
    ));
    final collectionList = collectionListR
        .map((g) => g.okOrNull)
        .whereType<fsa.FileSystemFileHandle>()
        .toList();
    if (collectionList.length != collections.length) return;

    final Map<String, List<MapEntry<Game, String>>> fullnameChange = {};
    gamesToRename.forEach((game, value) {
      if (game.filename != value.substring(0, value.lastIndexOf('.'))) {
        fullnameChange
            .putIfAbsent(game.system, () => [])
            .add(MapEntry(game, value));
      }
    });
    if (fullnameChange.isNotEmpty) {
      final downloadedMediaHandle = paths.downloadedMediaPath.handle;
      if (downloadedMediaHandle == null) {
        return _errorsStreamController.add(
          'No Downloaded Media path configured in settings.'
          ' Required for renaming game assets.',
        );
      }
      final permissions = await downloadedMediaHandle.requestPermission(
        mode: fsa.FileSystemPermissionMode.readwrite,
      );
      if (permissions != fsa.PermissionStateEnum.granted) return;

      for (final MapEntry(key: system, value: games)
          in fullnameChange.entries) {
        final dirR = await downloadedMediaHandle.getDirectoryHandle(system);
        if (dirR
            is! fsa.Ok<fsa.FileSystemDirectoryHandle, fsa.GetHandleError>) {
          _errorsStreamController.add(
            'No directory for system "$system" in Downloaded Media path.',
          );
          continue;
        }
        final directories = await dirR.value.entries().toList();
        for (final dirA
            in directories.whereType<fsa.FileSystemDirectoryHandle>()) {
          await Future.wait(games.map((g) {
            final MapEntry(key: game, :value) = g;
            return dirA.renameFile(
              '${game.filename}.png',
              '${value.substring(0, value.lastIndexOf('.'))}.png',
            );
          }));
        }
      }
    }

    /// Edit Files
    Future<void> replaceInHandles(
      List<fsa.FileSystemFileHandle> handles,
      (Pattern, String) Function(Game g, String newName) mapper,
    ) {
      return Future.wait(handles.map((c) async {
        String f = await (await c.getFile()).readAsString();
        for (final e in gamesToRename.entries) {
          final values = mapper(e.key, e.value);
          f = f.replaceAll(values.$1, values.$2);
        }
        final w = await c.createWritable(keepExistingData: false);
        await w.write(fsa.WriteChunkType.string(f));
        await w.close();
      }));
    }

    await replaceInHandles(
      collectionList,
      (g, n) => (g.romPath, '%ROMPATH%/${g.system}/$n'),
    );
    await replaceInHandles(
      gamelists,
      (g, n) => (
        '<path>${escapeXmlContent(g.path)}</path>',
        '<path>./${escapeXmlContent(n)}</path>'
      ),
    );

    /// Reselect the same games
    final newSelectedGameName = gamesToRename[selectedGame];
    await _loadGames();
    selectedGames = <Game>{
      ...selectedGames.map(
        (s) => allGames.firstWhere(
          (g) => g.path == './${gamesToRename[s] ?? s.relativePath}',
        ),
      ),
    };
    if (newSelectedGameName != null) {
      selectedGamePath = './$newSelectedGameName';
    }
  }

  Future<void> updateSelectedGamesCollection({
    required String collection,
    required bool add,
  }) async {
    if (selectedGames.isEmpty) return;

    final esDeHandle = paths.esDeAppDataConfigPath.handle;
    if (esDeHandle == null) throw Exception('');

    final collectionsDir =
        (await esDeHandle.getDirectoryHandle('collections')).okOrNull!;
    final collectionsFile = (await collectionsDir
            .getFileHandle('$customCollectionPrefix$collection.cfg'))
        .okOrNull;
    if (collectionsFile == null) throw Exception('');

    final p = await collectionsFile.requestPermission(
      mode: fsa.FileSystemPermissionMode.readwrite,
    );
    if (p != fsa.PermissionStateEnum.granted) return;

    final values = await (await collectionsFile.getFile()).readAsString();
    final list = values.split('\n');

    final toUpdate = selectedGames
        .where((g) => g.system != 'pc')
        .map((g) => g.romPath)
        .where((path) => add ? list.contains(path) : !list.contains(path));
    if (toUpdate.isNotEmpty) {
      final Iterable<String> items;
      if (add) {
        items = toUpdate;
      } else {
        items = list.where(toUpdate.contains);
      }
      final w = await collectionsFile.createWritable(keepExistingData: add);
      await w.write(
        fsa.WriteChunkType.string(items.join('\n')),
      );
      await w.close();
    }
  }

  Future<void> saveState() async {
    final data = jsonEncode(toData().toJson());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sharedPreferenceKey, data);
  }

  Future<void> _loadState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final storeData = prefs.getString(_sharedPreferenceKey);
    if (storeData != null) {
      final data = GameListData.fromJson(
        jsonDecode(storeData) as Map<String, dynamic>,
      );

      if (data.selectedGamePath != null) {
        selectedGamePath = data.selectedGamePath;
      }
      if (data.paths != null) {
        paths = data.paths!;
      }
      if (data.storedFilter != null) {
        storedFilterController.text = data.storedFilter!;
      }
      if (data.storedFilters != null) {
        storedFilters = data.storedFilters!;
      }
      if (data.showFilter != null) {
        showFilter = data.showFilter!;
      }
      if (data.isGridView != null) {
        isGridView = data.isGridView!;
      }
      if (data.imageAssetType != null) {
        imageAssetType = data.imageAssetType!;
      }
      if (data.isFiltering != null) {
        isFiltering = data.isFiltering!;
      }
      if (data.imageWidth != null) {
        imageWidth = data.imageWidth!;
      }
      notifyListeners();
    }
  }

  Future<void> _loadGames() async {
    final isInitialLoad = allGames.isEmpty;
    allGames.clear();
    final systemList = [('ps2', _gamelistPs2), ('genesis', _gamesXml)];

    fsa.FileSystemDirectoryHandle? gamelistsDir;
    fsa.FileSystemDirectoryHandle? collectionsDir;
    if (kIsWeb) {
      // TODO: abstract persistence
      final p = await fsa.FileSystem.instance.getPersistence();

      final esDeItem = paths.esDeAppDataConfigPath.persistedId == null
          ? null
          : p.get(paths.esDeAppDataConfigPath.persistedId!);
      final esDeHandle = esDeItem?.handle;
      if (esDeHandle is fsa.FileSystemDirectoryHandle) {
        paths.esDeAppDataConfigPath.handle = esDeHandle;
        gamelistsDir =
            (await esDeHandle.getDirectoryHandle('gamelists')).okOrNull;
        collectionsDir =
            (await esDeHandle.getDirectoryHandle('collections')).okOrNull;
      }

      final downloadedMediaItem = paths.downloadedMediaPath.persistedId == null
          ? null
          : p.get(paths.downloadedMediaPath.persistedId!);
      final downloadedMediaHandle = downloadedMediaItem?.handle;
      if (downloadedMediaHandle is fsa.FileSystemDirectoryHandle) {
        paths.downloadedMediaPath.handle = downloadedMediaHandle;
      }
    } else {
      paths.esDeAppDataConfigPath.handle = fsa.FileSystem.instance
              .getIoNativeHandleFromPath(esDeAppDataConfigPath.text)
          as fsa.FileSystemDirectoryHandle?;
      gamelistsDir = fsa.FileSystem.instance.getIoNativeHandleFromPath(
        '${esDeAppDataConfigPath.text}/gamelists',
      ) as fsa.FileSystemDirectoryHandle?;
      collectionsDir = fsa.FileSystem.instance.getIoNativeHandleFromPath(
        '${esDeAppDataConfigPath.text}/collections',
      ) as fsa.FileSystemDirectoryHandle?;

      paths.downloadedMediaPath.handle = fsa.FileSystem.instance
              .getIoNativeHandleFromPath(downloadedMediaPath.text)
          as fsa.FileSystemDirectoryHandle?;
    }
    final esDeDataHandle = paths.esDeAppDataConfigPath.handle;

    if (gamelistsDir != null) {
      systemList.clear();
      await for (final dir in gamelistsDir.entries()) {
        if (dir is fsa.FileSystemDirectoryHandle) {
          final f = await dir.getFileHandle('gamelist.xml');
          if (f is! fsa.Ok<fsa.FileSystemFileHandle, fsa.GetHandleError>) {
            continue;
          }
          final xmlFile = await f.value.getFile();
          final xml = await xmlFile.readAsString();
          systemList.add((dir.name.split(pathSeparator).last, xml));
        }
      }
      notifyListeners();
    }

    if (collectionsDir != null) {
      await for (final file in collectionsDir.entries()) {
        if (file is fsa.FileSystemFileHandle &&
            file.name.endsWith('.cfg') &&
            !file.name.startsWith('.')) {
          final collectionFile = await file.getFile();
          final collectionText = await collectionFile.readAsString();
          String name = file.name;
          name = name.substring(0, name.length - 4); // remove .cfg
          if (name.startsWith(customCollectionPrefix)) {
            name = name.substring(customCollectionPrefix.length);
          }
          collections[name] = collectionText.split('\n');
          final collectionId = name.toLowerCase().replaceAll(' ', '-');
          //   themes\canvas-es-de\_inc\systems\metadata-global\mario.xml
          final systemTheme = await esDeDataHandle!.getNestedFileHandle(
            'themes/canvas-es-de/_inc/systems/metadata-global/$collectionId.xml',
          );
          if (systemTheme
              is fsa.Ok<fsa.FileSystemFileHandle, fsa.GetHandleError>) {
            final xml =
                await (await systemTheme.value.getFile()).readAsString();
            final document = XmlDocument.parse(xml);
            collectionSystems[name] = ThemeSystem.fromXml(
              collectionId,
              document.getElement('theme')!.getElement('variables')!,
            );
          }
        }
      }
      collections.forEach((k, gl) {
        for (final g in gl) {
          final c = gameToCollection[g];
          if (c == null) {
            gameToCollection[g] = [k];
          } else {
            c.add(k);
          }
        }
      });
      notifyListeners();
    }
    for (var (system, xml) in systemList) {
      final altEmuIndex = xml.indexOf('<alternativeEmulator>');
      if (altEmuIndex != -1) {
        xml = xml.replaceRange(
          altEmuIndex,
          xml.indexOf('</alternativeEmulator>') +
              '</alternativeEmulator>'.length,
          '',
        );
      }

      final document = XmlDocument.parse(xml);
      allGames.addAll(
        document.findAllElements('game').map((e) => Game.fromXml(e, system)),
      );
    }

    fsa.FileSystemFileHandle? playniteDb;
    fsa.FileSystemFileHandle? companiesDb;
    fsa.FileSystemFileHandle? genresDb;
    fsa.FileSystemDirectoryHandle? playniteFiles;
    if (kIsWeb) {
      final p = await fsa.FileSystem.instance.getPersistence();

      final playniteItem = paths.playniteLibraryPath.persistedId == null
          ? null
          : p.get(paths.playniteLibraryPath.persistedId!);
      final playniteHandle = playniteItem?.handle;
      if (playniteHandle is fsa.FileSystemDirectoryHandle) {
        paths.playniteLibraryPath.handle = playniteHandle;
        playniteDb = (await playniteHandle.getFileHandle('games.db')).okOrNull;
        companiesDb =
            (await playniteHandle.getFileHandle('companies.db')).okOrNull;
        genresDb = (await playniteHandle.getFileHandle('genres.db')).okOrNull;
        playniteFiles =
            (await playniteHandle.getDirectoryHandle('files')).okOrNull;
      }
    } else {
      final p = playniteLibraryPath.text;
      paths.playniteLibraryPath.handle = fsa.FileSystem.instance
          .getIoNativeHandleFromPath(p) as fsa.FileSystemDirectoryHandle?;
      playniteDb = fsa.FileSystem.instance.getIoNativeHandleFromPath(
        '${p}games.db',
      ) as fsa.FileSystemFileHandle?;
      companiesDb = fsa.FileSystem.instance.getIoNativeHandleFromPath(
        '${p}companies.db',
      ) as fsa.FileSystemFileHandle?;
      genresDb = fsa.FileSystem.instance.getIoNativeHandleFromPath(
        '${p}genres.db',
      ) as fsa.FileSystemFileHandle?;
      playniteFiles = fsa.FileSystem.instance.getIoNativeHandleFromPath(
        '${p}files',
      ) as fsa.FileSystemDirectoryHandle?;
    }
    if (playniteDb != null) {
      final bytes = await (await playniteDb.getFile()).readAsBytes();
      final companiesBytes = companiesDb != null
          ? await (await companiesDb.getFile()).readAsBytes()
          : null;
      final genresBytes = genresDb != null
          ? await (await genresDb.getFile()).readAsBytes()
          : null;

      final gameToAssets = <String, List<String>>{};
      if (playniteFiles != null) {
        final assetsList = await playniteFiles.entries().toList();
        for (final assetDir in assetsList) {
          if (assetDir is! fsa.FileSystemDirectoryHandle) continue;
          await for (final asset in assetDir.entries()) {
            if (asset is fsa.FileSystemFileHandle &&
                !asset.filename.startsWith('.') &&
                const [
                  'ico',
                  'png',
                  'jpg',
                  'jpeg',
                  'gif',
                  'bmp',
                  'svg',
                ].contains(
                  asset.name.substring(asset.name.lastIndexOf('.') + 1),
                )) {
              gameToAssets
                  .putIfAbsent(assetDir.filename, () => [])
                  .add('${assetDir.name}/${asset.filename}');
            }
          }
        }
      }

      final playniteGames = parsePlayniteDb(
        bytes,
        companies: companiesBytes,
        genres: genresBytes,
        gameToAssets: gameToAssets,
      );

      allGames.addAll(playniteGames);
      notifyListeners();
    }

    for (final g in allGames) {
      systems.add(g.system);
      if (g.genre != null) genres.add(g.genre!);
      if (g.publisher != null) publishers.add(g.publisher!);
      if (g.developer != null) developers.add(g.developer!);
    }
    if (!isInitialLoad) {
      filterGames();
    } else if (storedFilters.containsKey(storedFilterController.text)) {
      selectFilter(storedFilterController.text);
    }
    notifyListeners();
  }

  void toggleListGridView() {
    isGridView = !isGridView;
    notifyListeners();
  }

  void storeFilter() => filterGames(store: true);

  void filterGames({bool store = false}) {
    final gameFilter =
        GameFilter.fromJson(filterController.rootOutputData as Map);
    if (store) {
      storedFilters[storedFilterController.text.trim()] = gameFilter;
    }
    _applyFilter(gameFilter);
  }

  void _applyFilter(GameFilter gameFilter) {
    games = allGames
        .where(
          (g) => gameFilter.applies(
            g,
            gameToCollection[g.romPath] ?? const [],
          ),
        )
        .toList();
    if (gameFilter.order.isNotEmpty) {
      games.sort(gameFilter.compare);
    }
    notifyListeners();
  }

  void clearFilter() {
    filterController = JsonFormController(initialData: {});
    games = allGames;
    notifyListeners();
  }

  void selectFilter(String? value) {
    final filter = storedFilters[value];
    if (filter != null) {
      filterController = JsonFormController(initialData: filter.toJson());
      _applyFilter(filter);
    }
  }

  void toggleFilter() {
    isFiltering = !isFiltering;
    notifyListeners();
  }

  void deleteFilter() {
    storedFilters.remove(storedFilterController.text);
    notifyListeners();
  }

  Future<void> selectDirectory(GameListPath path) async {
    final result = await fsa.FileSystem.instance.showDirectoryPicker();
    if (result != null) {
      await path.setHandle(result);
      final dmPath = paths.downloadedMediaPath;
      if (path == paths.esDeAppDataConfigPath && dmPath.handle == null) {
        final downloadedMediaDir =
            (await result.getDirectoryHandle('downloaded_media')).okOrNull;
        if (downloadedMediaDir != null) {
          await dmPath.setHandle(downloadedMediaDir);
        }
      }
      if (path == paths.esDeAppDataConfigPath ||
          path == paths.playniteLibraryPath) {
        _loadGames();
      } else {
        notifyListeners();
      }
    }
  }

  void toggleSelectingGames() {
    if (isSelectingGames) {
      selectedGames.clear();
    }
    isSelectingGames = !isSelectingGames;
    notifyListeners();
  }

  void selectGame(Game item) {
    // Shift: select range from last selected to item
    if (shiftPressed && selectedGames.isNotEmpty) {
      final lastSelected = selectedGames.last;
      final range = [games.indexOf(lastSelected), games.indexOf(item)]..sort();
      selectedGames.addAll(games.getRange(range.first, range.last + 1));
    } else if (selectedGames.contains(item)) {
      selectedGames.remove(item);
    } else {
      selectedGames.add(item);
    }
    isSelectingGames = true;
    notifyListeners();
  }

  void updateSelectedGames(SelectedGamesAction action) {
    switch (action) {
      case SelectedGamesAction.selectAll:
        selectedGames = Set.from(games);
      case SelectedGamesAction.clearSelection:
        selectedGames.clear();
      case SelectedGamesAction.invertSelection:
        if (selectedGames.isEmpty) {
          selectedGames = Set.from(games);
        } else if (selectedGames.length == games.length) {
          selectedGames.clear();
        } else {
          selectedGames =
              games.where((g) => !selectedGames.contains(g)).toSet();
        }
      default:
    }
    notifyListeners();
  }

  void selectCollection(String collection) {
    selectedCollection = collection;
    notifyListeners();
  }

  void createSystemCollection(
    String collection,
    ThemeSystem system,
  ) {
    // TODO: create system from collection
  }

  void orderBy(GameOrderKind kind) {
    final field = filterController.retrieveField('order')!;
    final list = [...(field.value as List)];
    final index = list.indexWhere((a) => a != null && a['kind'] == kind.name);
    final Map<String, Object?> item;
    if (index == -1) {
      item = {'kind': kind.name, 'isDesc': false};
    } else {
      item = {...list.removeAt(index)!};
      item['isDesc'] = !(item['isDesc'] as bool? ?? true);
    }
    list.insert(0, item);
    field.value = list;
  }
}

final pathSeparator = RegExp(r'[/\\]');
bool endsWithPathSeparator(String value) =>
    value.isNotEmpty && value.lastIndexOf(pathSeparator) == value.length - 1;

extension FileSystemHandleName on fsa.FileSystemHandle {
  String get filename => name.substring(
        name.lastIndexOf(RegExp(r'[/\\].')) + 1,
        endsWithPathSeparator(name) ? name.length - 1 : null,
      );
}

extension FileSystemHandleDir on fsa.FileSystemDirectoryHandle {
  Future<fsa.Result<fsa.FileSystemFileHandle, fsa.GetHandleError>>
      getNestedFileHandle(String path, {bool? create}) async {
    final index = path.lastIndexOf(pathSeparator);
    final dirR = await getNestedDirectoryHandle(
      path.substring(0, index),
      create: create,
    );
    if (dirR is! fsa.Ok<fsa.FileSystemDirectoryHandle, fsa.GetHandleError>) {
      return fsa.Err(dirR.errOrNull!);
    }
    return dirR.value.getFileHandle(path.substring(index + 1), create: create);
  }

  Future<fsa.Result<fsa.FileSystemDirectoryHandle, fsa.GetHandleError>>
      getNestedDirectoryHandle(String path, {bool? create}) async {
    final paths = path
        .split(pathSeparator)
        .where((v) => v.isNotEmpty)
        .toList(growable: false);
    fsa.FileSystemDirectoryHandle dir = this;
    for (final p in paths) {
      final d = await dir.getDirectoryHandle(p, create: create);
      if (d is! fsa.Ok<fsa.FileSystemDirectoryHandle, fsa.GetHandleError>) {
        return d;
      }
      dir = d.value;
    }
    return fsa.Ok(dir);
  }

  Future<fsa.Result<void, fsa.GetHandleError>> renameFile(
    String initialPath,
    String newPath,
  ) async {
    if (!kIsWeb) {
      // TODO: rename name to path
      await io.File('$name/$initialPath').rename('$name/$newPath');
      return fsa.Ok(null);
    }
    final initialName =
        initialPath.substring(initialPath.lastIndexOf(pathSeparator) + 1);
    final dirR = await getNestedDirectoryHandle(
      initialPath.substring(0, initialPath.lastIndexOf(pathSeparator)),
    );
    if (dirR is! fsa.Ok<fsa.FileSystemDirectoryHandle, fsa.GetHandleError>) {
      return dirR;
    }

    final previousFile = await dirR.value.getFileHandle(initialName);
    if (previousFile is! fsa.Ok<fsa.FileSystemFileHandle, fsa.GetHandleError>) {
      return previousFile;
    }
    final newFile = await getNestedFileHandle(newPath, create: true);
    if (newFile is! fsa.Ok<fsa.FileSystemFileHandle, fsa.GetHandleError>) {
      return newFile;
    }

    final f = await previousFile.value.getFile();
    final bytes = await f.readAsBytes();
    final writable =
        await newFile.value.createWritable(keepExistingData: false);
    await writable.write(fsa.WriteChunkType.bufferSource(bytes.buffer));
    await writable.close();

    await dirR.value.removeEntry(initialName);
    return fsa.Ok(null);
  }
}

enum SelectedGamesAction {
  addToCollection,
  removeFromCollection,
  changeFileExtension,
  selectAll,
  clearSelection,
  invertSelection,
}

// C:\Users\jmanu\EmuDeck\EmulationStation-DE\ES-DE\gamelists
const _gamesXml = '''
<?xml version="1.0"?>
<gameList>
	<game>
		<path>./Aladdin (E) [!].zip</path>
		<name>Aladdin</name>
		<desc>The game from Virgin based on the 1992 animated Disney film is a side-scrolling platformer.

The player controls Aladdin, who must make his way through several levels based on locations from the movie: from the streets and rooftops of Agrabah, the Cave of Wonders and the Sultan's dungeon to the final confrontation in Grand Vizier Jafar's palace. The Sultan's guards and also animals of the desert want to hinder Aladdin in his way. He can defend himself with his sword or by throwing apples. Next to apples, Aladdin can also collect gems which can be traded for lives and continues with a traveling trader. Finding Genie or Abu icons enables bonus rounds. The Genie bonus round is a game of luck played for apples, gems or extra lives. In Abu's bonus round, the player controls the little monkey who has to catch bonus items that fall from the sky, but without touching any of the unwanted objects like rocks and pots.

The game's humorous animations were created by Walt Disney Feature Animation.
</desc>
		<rating>0.9</rating>
		<releasedate>19931111T000000</releasedate>
		<developer>Virgin</developer>
		<publisher>SEGA</publisher>
		<genre>Platform</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Castlevania - Bloodlines (U) [!].zip</path>
		<name>Castlevania : Bloodlines</name>
		<desc>In the year 1917, evil had threatened to rise up again in Transylvania. A young lady named Elizabeth Bartley, who was tried as a witch and killed centuries before, was planning to resurrect the Prince of Darkness, Count Dracula, once again.

The latest of the Belmont lineage, John Morris, and his friend Eric Lecarde, must now travel across Europe to the Palace of Versailles in France, where Bartley is planning the resurrection. And in their way stands Dracula's strongest followers yet...</desc>
		<rating>0.9</rating>
		<releasedate>19940317T000000</releasedate>
		<developer>Konami</developer>
		<publisher>Konami</publisher>
		<genre>Platform</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Combat Cars (JUE) [!].zip</path>
		<name>Combat Cars</name>
		<desc>Combat Cars is a racing game in which the player not only competes with other cars, trying to outrun them, but also uses all kinds of weapons and gadgets to damage their opponents. In the beginning of the game, the player can choose one of the eight available characters. Each character has his/her own strengths and weaknesses (speed, car handling, etc.), as well as unique weapons. The weapons include a simple gun, glue spots they can leave to trap other cars, homing missile, and others. There are 24 different tracks available in the game. The player must complete them in a linear fashion, and once they run out of time, the game is over.</desc>
		<rating>0.5</rating>
		<releasedate>19940101T000000</releasedate>
		<developer>Accolade</developer>
		<publisher>Accolade</publisher>
		<genre>Racing, Driving</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Contra - Hard Corps (U) [!].zip</path>
		<name>Contra : Hard Corps</name>
		<desc>While the original arcade games, as well as a few computer conversions under the Gryzor title, were released unchanged in Europe, subsequent console installments of the Contra were released under the Probotector title in Europe.</desc>
		<rating>0.9</rating>
		<releasedate>19940808T000000</releasedate>
		<developer>Konami</developer>
		<publisher>Konami</publisher>
		<genre>Shooter / Run and Gun</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Dr. Robotnik's Mean Bean Machine (U) [!].zip</path>
		<name>Dr. Robotnik's Mean Bean Machine</name>
		<desc>Set on planet Mobius, Dr. Robotnik has hatched a new plan to menace the world and its inhabitants - by kidnapping the citizens of Beanville and turning them into devious robot slaves, the doctor will create an army that will help him rid the planet of music and fun forever. To this end, he has created a giant roboticizing machine called the "Mean Bean-Steaming Machine" to use on the jolly bean folk. Putting his plan into motion, Robotnik sends out his henchbots to round up all the unfortunate bean folk and group them together in dark dungeons so they can be sent to the Mean Bean-Steaming Machine.

Assuming the role of Has Bean, the player must now stand up against Robotnik's henchmen by breaking into the dungeons, freeing the bean folk before it is too late, and get through Robotnik's henchbots to the deranged doctor himself and foil his evil plans once and for all.</desc>
		<rating>0.8</rating>
		<releasedate>19931201T000000</releasedate>
		<developer>Compile</developer>
		<publisher>SEGA</publisher>
		<genre>Puzzle</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Earthworm Jim (E) [!].zip</path>
		<name>Earthworm Jim</name>
		<desc>A crow is chasing a worm named Jim while in outer space Psy-Crow is chasing a renegade ship. The ship's captain has stolen an ultra-high-tech-indestructible-super-space-cyber-suit and Queen Slug-for-a-Butt has ordered Psy-Crow to get it, since it can make her more beautiful than Princess-What's-Her-Name. Psy-Crow blasts the captain and the suit falls to Planet Earth.

Back on earth Jim wonders if he is finally safe when an ultra-high-tech-indestructible-super-space-cyber-suit lands on him. Luckily Jim rests in the neck ring of the suit. Then the space particles begin interacting with Jim, causing a light-speed evolution. Jim soon realizes he is in control of the suit.

Jim overhears the Queen's plans for the suit and decides to meet this Princess...</desc>
		<rating>0.8</rating>
		<releasedate>19940802T000000</releasedate>
		<developer>Shiny Entertainment</developer>
		<publisher>Virgin Interactive Entertainment</publisher>
		<genre>Platform</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Earthworm Jim 2 (U).zip</path>
		<name>Earthworm Jim 2</name>
		<desc>An ordinary average earthworm named Jim goes about his normal daily life, cruising around avoiding crows and doing other general worm-like things. Jim is suddenly struck by a very large ultra- high- tech- indestructible- super- space- cyber- suit. Through sheer luck, Jim rests safely in the neck ring of the suit. 

Suddenly, the ultra-high-tech space particles of the suit begin interacting with Jim's soft wormy flesh. A radical light-speed evolution takes place.

Jim soon realizes he is in control of the suit.

Gameplay is similar to the first game, with Jim jumping and running through the levels. There are 5 weapons more than the original game to collect. Characters like Princess Whats-Her-Name and Psy-Crow appear.</desc>
		<rating>0.9</rating>
		<releasedate>19951115T000000</releasedate>
		<developer>Playmates Interactive</developer>
		<publisher>Virgin Interactive Entertainment</publisher>
		<genre>Platform</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Gunstar Heroes (E) [!].zip</path>
		<name>Gunstar Heroes</name>
		<desc>Chaos has broken out on the planet Gunstar-9!!

The mad Colonel Red has discovered four crystals that imprison a deadly being known as GoldenSilver, and plans on unleashing it onto the population of the planet! He must be stopped! Enter...the Gunstar Heroes, Red and Blue!

Unleash some mad blasting action onto the Colonel's army and don't let him bring GoldenSilver to life!! The fate of Gunstar-9 is in your hands!</desc>
		<rating>0.8</rating>
		<releasedate>19930909T000000</releasedate>
		<developer>Treasure</developer>
		<publisher>SEGA</publisher>
		<genre>Platform / Shooter Scrolling</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Land Stalker (U).zip</path>
		<name>Landstalker</name>
		<desc>A jovial fantasy yarn, Landstalker is the title that put Climax Entertainment on the map.  Following the exploits of elvish treasure hunter, Nigel, and his pixie friend, Friday, they travel to a distant island to find the long lost treasure of King Nole.

The game can draw many parallels to the Zelda series, due to the game’s mostly whimsical style and emphasis on item collecting.  However, Landstalker is more meticulous, moving at a slower and more developed rate, with an abundance of towns and NPCs rounding out the cast.
</desc>
		<rating>0.9</rating>
		<releasedate>19931001T000000</releasedate>
		<developer>Climax</developer>
		<publisher>SEGA</publisher>
		<genre>Role Playing Game</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Landstalker - The Treasures of King Nole (E) (Eng) [!].zip</path>
		<name>Landstalker</name>
		<desc>A jovial fantasy yarn, Landstalker is the title that put Climax Entertainment on the map.  Following the exploits of elvish treasure hunter, Nigel, and his pixie friend, Friday, they travel to a distant island to find the long lost treasure of King Nole.

The game can draw many parallels to the Zelda series, due to the game’s mostly whimsical style and emphasis on item collecting.  However, Landstalker is more meticulous, moving at a slower and more developed rate, with an abundance of towns and NPCs rounding out the cast.
</desc>
		<rating>0.9</rating>
		<releasedate>19931001T000000</releasedate>
		<developer>Climax</developer>
		<publisher>SEGA</publisher>
		<genre>Role Playing Game</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Mega Bomberman (UE).zip</path>
		<name>Mega Bomberman</name>
		<desc>Mega Bomberman is a top down strategy game. Control your Bomberman through various levels defeating multiple enemies and plenty of bosses. Each level consist of blocks for exploding and some blocks that don't explode. At times you will need the non-exploding blocks as shelter. The blocks that do explode reveal power-ups and eggs. 

The eggs are the unique twist to this version of Bomberman. When you get a egg, it hatches into a kangaroo. There are multiple kangaroo types, each with their own unique ability. You hop on the back of the kangaroo and utilize it's ability. If you happen to walk into an explosion the kangaroo takes the damage and dies and you continue to live. 

Another unique feature in multiplayer is you can choose your character. Pick one of 9 such as Miner, Tiny, Fat, Cop, Punk(On cover), Lady, Old man, Robot and the original Bomberman.

After selecting your character get ready for battle as you are placed in 1 of the 4 corners of the arena. Now just blow your way through the blocks and attack some opponents. Watch out for their bombs and remember to dodge your own. There are also many arena's to choose from. Each arena has it's own twist such as trap doors, an igloo to hide in, conveyor belts and more.</desc>
		<rating>0.9</rating>
		<releasedate>19941001T000000</releasedate>
		<developer>Westone</developer>
		<publisher>SEGA</publisher>
		<genre>Action</genre>
		<players>1-4</players>
	</game>
	<game>
		<path>./Mortal Combat 5 (Unl) [c][!].zip</path>
		<name>Mk 5 - Mortal Combat - Subzero</name>
		<desc>MK5 - Mortal Combat - Sub Zero is a pirated port of Mortal Kombat Mythologies: Sub-Zero for PlayStation and Nintendo 64.

This game uses the system of Mortal Kombat Mythologies in that it's a cross between fighting and side-scrolling. The controls are somewhat awkward; during fights, Sub-Zero won't automatically turn around when behind an opponent, forcing the player to use the A button to turn around. The fighting engine isn't taken from the official Mortal Kombat games and instead uses an engine similar to one used in some other pirated Mega Drive fighting games. All of the opponents in this game are clones of major Mortal Kombat characters. There are four levels, each with a different set of clones to fight.</desc>
		<genre>Fighting</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Mortal Kombat (JUE) (REV 00) [!].zip</path>
		<name>Mortal Kombat</name>
		<desc>Five Hundred years ago, an ancient and well respected Shaolin fighting tournament, held every 50 years, was corrupted by an evil and elderly sorcerer by the name of Shang Tsung.  Shang was accompanied by Prince Goro, a warrior of the Shokan race (a four armed half-human/half-dragon). Knowing that if ten tournaments in a row were won by the Outworld champion, the Earth Realm would be conquered by evil and fall into darkness, Shang entered Goro in the tournament and had him defeat the great Kung Lao. Goro has been  reigning supreme as the undefeated fighting champion for five hundred years now. As the last tournament required draws near, Raiden, Thunder God and protector of the Earth Realm, enacts a plan to tip the scales in the humans favor, Seven fighters step into the arena on Shang Tsung's mysterious island: Shaolin warrior Liu Kang, Special Forces operative Sonya Blade, the mercenary thug Kano, fame-seeking actor Johnny Cage, the ice wielding Lin Kuei warrior Sub-Zero and his undead adversary Scorpion, and Raiden himself.

Mortal Kombat is a side-scrolling 1 on 1 fighting game. Fighting is set as one on one kombat, allowing each player to perform a variety of punches, kicks, and special moves in order to defeat their opponent.  When the opponent faces their second round loss, the winner can perform a finishing move called a "Fatality" on the loser.  The Fatality is a move unique to each fighter that graphically kills the loser in a blood-soaked finale.

Mortal Kombat began its life as a 2-player arcade title. It is notable for its use of digitized actors to represent the game's fighters, as well as its use of copious amounts of blood during gameplay.</desc>
		<rating>0.8</rating>
		<releasedate>19930913T000000</releasedate>
		<developer>Midway</developer>
		<publisher>Acclaim</publisher>
		<genre>Fighting</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Mortal Kombat 3 (4) [!].zip</path>
		<name>Mortal Kombat III</name>
		<desc>Shao Kahn has won. The Earthrealm is no more. In order to revive his Queen Sindel, the emperor Shao Kahn used the Outworld Tournament from Mortal Kombat 2 as a diversion while his Shadow Priests revive his fallen Queen on Earth. Once enacted, the dimensional bridge between the two realms connects, allowing Kahn's extermination squads to invade and destroy Earth, and enslave the population's souls.

A small team of Raiden's "Chosen Warriors" survives the attack: Mortal Kombat champion Liu Kang and his ally Kung Lao, Special Forces agents Sonya Blade and Jax, the shaman Nightwolf, the riot cop Stryker, the nomadic Kabal, and former Lin Kuei warrior Sub-Zero, who has gone rogue from his clan. Facing the warriors are the mercenary Kano, cyber-ninjas Smoke, Sektor and Cyrax, Sheeva, a female Shokan, the sorcerer Shang Tsung, and Queen Sindel herself.

Mortal Kombat 3 brings new elements to the 2D fighting series: multi-level playfields, "Dial-A-Combo" attacks, a "Run" button to speed up the battles, and "Vs." codes, which unlock new powers and abilities once both players enter a code sequence in pre-match-up screens. Also included are more stage fatalities and finishing moves as each warrior attempts to go one-on-one with the Centaurian enforcer Motaro, and Shao Kahn himself.

Mortal Kombat 3 is the last traditional one-on-one fighting game game in the series to feature motion-captured digitized graphics for its kombatants, and introduces online network play to the PC version.</desc>
		<rating>0.9</rating>
		<releasedate>19950101T000000</releasedate>
		<developer>Midway</developer>
		<publisher>Acclaim</publisher>
		<genre>Fighting</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Mortal Kombat II (JUE) [!].zip</path>
		<name>Mortal Kombat II</name>
		<desc>The Mortal Kombat fighters, plus several new ones, return for a tournament held by the evil Shang Tsung of the Outworld. The action is one-on-one as before, and famed for its high level of violence and blood (other than the sanitised Nintendo version). There are 5 difficulty levels and optional credits, as well as the usual two player mode including same character duels.

To win the main tournament, the player must beat each of the other human players, before taking on Shang Tsung, Kintaro and finally Shao Kahn. Players have a range of punches and kicks available, as well as flying kicks, uppercuts, roundhouses, and the special moves, which vary for each player. These include throws, uppercuts, long-distance bullets, bicycle kicks and a teleport feature.</desc>
		<rating>0.8</rating>
		<releasedate>19940101T000000</releasedate>
		<developer>Midway</developer>
		<publisher>Acclaim</publisher>
		<genre>Fighting</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Ms. Pac-Man (U) [!].zip</path>
		<name>Ms. Pac-Man</name>
		<desc>In 1982, a sequel to the  incredibly popular Pac-Man was introduced in the form of his girlfriend, Ms. Pac-Man.  This sequel continued on the "eat the dots/avoid the ghosts" gameplay of the original game, but added new features to keep the title fresh.

Like her boyfriend, Ms. Pac-Man attempts to clear four various and challenging mazes filled with dots and ever-moving bouncing fruit  while avoiding Inky, Blinky, Pinky and Sue, each with their own personalities and tactics.  One touch from any of these ghosts means a loss of life for Ms. Pac-Man.

Ms. Pac-Man can turn the tables on her pursuers by eating one of the four Energizers located within the maze. During this time, the ghosts turn blue, and Ms. Pac-Man can eat them for bonus points (ranging from 200, 400, 800 and 1600, progressively). The Energizer power only lasts for a limited amount of time, as the ghost's eyes float back to their center box, and regenerate to chase after Ms. Pac-Man again.

Survive a few rounds of gameplay, and the player will be treated to humorous intermissions showing the growing romantic relationship between Pac-Man and Ms. Pac-Man, leading all the way up to the arrival of "Junior".</desc>
		<rating>0.8</rating>
		<releasedate>19910701T000000</releasedate>
		<developer>Innerprise Software</developer>
		<publisher>Time Warner Interactive</publisher>
		<genre>Action</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Rocket Knight Adventures (E).zip</path>
		<name>Rocket Knight Adventures</name>
		<desc>Rocket Knight Adventures is the first side-scrolling action game starring Sparkster.  He lives in the kingdom of Zebulos, and is the bravest of all the Rocket Knights.  One day, an army of pigs comes down to invade the kingdom and capture the princess.  It is up to Sparkster to set things right again.

Most of the gameplay in Rocket Knight Adventures involves using Sparkster's rocket pack and sword.  Sparkster has to fight off many bosses and survive many precarious situations.  The levels are interspersed with a variety of elements, like shooting stages, and giant robot combat.</desc>
		<rating>0.8</rating>
		<releasedate>19930801T000000</releasedate>
		<developer>Konami</developer>
		<publisher>Konami</publisher>
		<genre>Platform</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Shining Force (U) [!].zip</path>
		<name>Shining Force</name>
		<desc>In a wondrous land perhaps not so far from our world, a strange and terrible series of events took place. The powers of darkness, led by Dark Dragon, fought for control of the world of Rune. Legendary warriors of light fought them with the ancient and modern weapons of the time, and drove Dark Dragon into another dimension. But Dark Dragon vowed that in 1,000 years, he would be able to break through the inter-dimensional barrier, back into this world. 

A thousand years of peace and tranquility passed. The people of the world were happy to live their lives in contentment, able to spend time rediscovering the magical and technological wonders destroyed by Dark Dragon and using them to benefit all people. 

But the kingdom of Runefaust has begun a massive attack of the kingdoms of Rune - intending to help Dark Dragon return to this world! A small band of warriors has been sent out on a dangerous journey to fight against the dark forces of Runefaust, and you are the leader. Prepare yourself for the ultimate battle! 

Shining Force is a strategy/RPG.  As you make your way through the lands of Rune, you will be joined by other warriors who wish to stop the forces of Runefaust.  Each warrior has their own strengths and weaknesses.  As you progress through the game you will also gain new weapons and spells.  Use them wisely to stop Dark Dragon from arising and causing havoc in Rune.</desc>
		<rating>0.8</rating>
		<releasedate>19930101T000000</releasedate>
		<developer>Climax</developer>
		<publisher>SEGA</publisher>
		<genre>Role Playing Game</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Shining Force II (E) [!].zip</path>
		<name>Shining Force II</name>
		<desc>Shining Force II is a strategy/RPG hybrid with cartoon-like graphics. The game is comprised of two modes: exploration, in which the hero and his companions engage in the role-playing game standard of talking to townspeople, exploring new lands, and furthering the plot; and battle mode, in which the combat is resolved from a tactical point of view, with individual combats being resolved from a close-up view with animated characters.

The plot consists of such quests as saving a princess from the clutches of demons, rebuilding the hero's hometown, and uniting the various forces of good together against the hero's nemesis. Along the way, the hero will be joined by many characters who seek to aid him in his journey. Several of these characters can only be obtained by completing side quests. In addition, random battles can occur between the programmed scenarios, giving the hero's party a chance to obtain experience and gain levels outside of the set scenarios.

There are several difficulty levels in the game, selectable when starting a new game. In addition, there is a configuration code that allows cheats to be activated, including the ability to control the enemy units.</desc>
		<rating>0.8</rating>
		<releasedate>19941002T000000</releasedate>
		<developer>Camelot Software</developer>
		<publisher>SEGA</publisher>
		<genre>Role Playing Game</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Shinobi 3 - Return of the Ninja Master (U) [!].zip</path>
		<name>Shinobi III : Return of the Ninja Master</name>
		<desc>Shinobi III involves a ninja named Joe "Shinobi" Musashi (you) going and kicking some bad guy butt, in this case his old enemy "Neo Zeed".

In normal Shinobi style, you are presented with side-scrolling playfields which you must slash and shuriken your way through, to meet the end boss of each round.
</desc>
		<rating>0.9</rating>
		<releasedate>19930822T000000</releasedate>
		<developer>Megasoft</developer>
		<publisher>SEGA</publisher>
		<genre>Platform</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Sonic and Knuckles &amp; Sonic 3 (JUE) [!].zip</path>
		<name>Sonic &amp; Knuckles + Sonic The Hedgehog 3</name>
		<desc>Dr. Eggman's (AKA Dr. Robotnik's) Death Egg was once again blasted by Sonic, crash-landing on the peak of a volcano on the Floating Island.
Dr. Eggman is still at large, and Sonic can't allow him to get his hands on the Master Emerald and repair the Death Egg. Sonic must also keep Knuckles off his back but Knuckles has problems too. As guardian of the Floating Island and all the Emeralds, Knuckles must do his part to keep the island safe. While they're going the rounds with each other, who will stop Dr. Eggman? </desc>
		<rating>0.9</rating>
		<releasedate>19941018T000000</releasedate>
		<developer>Sonic Team</developer>
		<publisher>SEGA</publisher>
		<genre>Platform</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Sonic the Hedgehog (JUE) [!].zip</path>
		<name>Sonic The Hedgehog</name>
		<desc>Sonic the Hedgehog is the first of many games starring Sega's premier rodent Sonic. It's a side scrolling platform game with a difference: speed. Sonic rushes through levels with incredible speed, allowing him to traverse loops and jumps with ease. The evil Dr. Robotnik has captured many of Sonic's animal friends and trapped them inside robots. Sonic can free his friends by destroying the robots with his spin attack. Meanwhile, Dr. Robotnik is trying to control the all-powerful chaos emeralds and Sonic must grab them before he does in the 3D rotating bonus levels. Sonic's weapon is his spin attack; while jumping, Sonic destroys hostile robots by touch. Throughout the platforming levels Sonic collects numerous rings. If Sonic is hit by an enemy, all the rings he's carrying fall out and scatter around; Sonic can quickly grab the rings back before they disappear. If Sonic is hit while not carrying any rings, he dies. Collecting 100 rings gives Sonic an extra life. There is also an invincibility bonus which temporarily protects Sonic from all attacks. The game is divided into several "zones", each of them containing three levels. At the end of each zone Sonic confronts Dr. Robotnik in a boss fight. Sonic the Hedgehog is a significant game because it gave Sega it's first real mascot, and established the Genesis as the video game system with "attitude."</desc>
		<rating>0.8</rating>
		<releasedate>19910623T000000</releasedate>
		<developer>SEGA</developer>
		<publisher>SEGA</publisher>
		<genre>Platform</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Sonic the Hedgehog 2 (JUE) [!].zip</path>
		<name>Sonic The Hedgehog 2</name>
		<desc>Sonic the Hedgehog 2 is a side-scrolling platformer based around speed, and the sequel to Sonic the Hedgehog. Players run through different worlds called "Zones", each with a specific theme. There are two Acts in nearly all of the 10 Zones, and at the end of each Zone's last Act is a machine that Robotnik controls, which you must defeat to progress. Sonic and Tails can collect rings which are scattered throughout all of the levels. When the player collects 100 rings they earn an extra life. The rings also act as protection - if Sonic is hurt when he is carrying rings, they scatter everywhere and he is briefly invincible. If he is hit again when he has no rings, he'll lose a life. If the player reaches a continue point lamppost with 50 or more rings, they'll be able to access the Special Stage. In this stage, you must gather a set amount of rings in a halfpipe-like stage before you reach a checkpoint. Complete all the checkpoints and you'll earn one of the seven Chaos Emeralds. The game also includes the ability to play the game co-op with a friend - at any time, a player can plug in a second controller and take over the AI controlled Tails. Tails has infinite lives and the camera remains focused on Sonic, meaning that Tails will not hinder play. Sonic (and Tails) can now also get speed from a standing start by holding down and repeatedly pressing the jump button for a "Spin Dash". This is useful when stuck near steep slopes or other areas where you need some momentum. The game also features a 2-player versus mode. This mode is a horizontally split-screen race through levels based on three of the zones in the single player game.</desc>
		<rating>0.8</rating>
		<releasedate>19921124T000000</releasedate>
		<developer>SEGA</developer>
		<publisher>SEGA</publisher>
		<genre>Platform</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Sonic the Hedgehog 3 (E).zip</path>
		<name>Sonic The Hedgehog 3</name>
		<desc>Sonic the Hedgehog 3 is the third in the Sonic series of games. As with the previous games, it is a side-scrolling platformer based around speed. The basic game remains the same - players collect rings to earn extra lives, which are also used for protection, and scatter everywhere when Sonic is hurt. Sonic can jump on enemies to defeat them, and Spin Dash by holding down and the jump button, then letting go of down. Dr. Robotnik's Death Egg has crash-landed on Floating Island, so called because it harnesses the power of the Chaos Emeralds to float in the air. Robotnik needs them to repair the Death Egg, so he tells the guardian of Floating Island, Knuckles the Echidna, that Sonic and Tails are there to steal them. With Knuckles tricked and trying to stop the heroes at every turn, will they be able to stop Robotnik in time? New to Sonic 3 are three different types of shields; the Fire Shield (which protects you from fire but disappears if you enter water), the Water Shield (which lets you breathe underwater infinitely), and the Electric Shield (which pulls nearby rings towards you). </desc>
		<rating>0.8</rating>
		<releasedate>19940123T000000</releasedate>
		<developer>Sonic Team</developer>
		<publisher>SEGA</publisher>
		<genre>Platform</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Street Fighter 2 Special Champion Edition (E) [!].zip</path>
		<name>Street Fighter II' : Special Champion Edition</name>
		<desc>From the corners of the globe come twelve of the toughest fighters to ever prowl the streets. Choose your champion and step into the arena as one of the eight original challengers or as one of the four Grand Masters! Pound your opponent as Balrog and knock them out for the count. Tower over your prey as Sagat and daze them with your awesome Tiger Shot. Slash your opponent with Vega's claw and send them running for cover. Or strike fear into your enemies as M. Bison, the greatest Grand Master of them all!</desc>
		<rating>0.9</rating>
		<releasedate>19930101T000000</releasedate>
		<developer>Capcom</developer>
		<publisher>SEGA</publisher>
		<genre>Fighting</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Streets of Rage (JUE) (REV 00) [!].zip</path>
		<name>Streets of Rage</name>
		<desc>Streets of Rage, Sega's answer to Final Fight, follows the story of three young police officers (Adam Hunter, Axel Stone and Blaze Fielding) in a city controlled by a criminal syndicate led by a "Mr. X" where crime is rampant, which leads the three heroes to make a pact to leave the force and topple the syndicate by themselves.

Gameplay is straightforward and simple. Three buttons are used, one to jump, other to attack and another to perform a range attack from a support police car. Each character has a limited set of moves that include punching and kicking or performing a back attack (if in the open), two grapple moves (depending if holding the opponent in front or by the back), a flying attack, and if playing with another player two additional tag attacks, and different abilities: Adam is slow, but a good jumper and a hard hitter, Axel fast and also a hard hitter, but a lousy jumper and Blaze fast and a good jumper, but weak hitter.
Levels are in typical arcade side-scroller fashion: move from left to right (with two exceptions), clearing screens from enemies one after another as fast as possible while avoid taking damage with a boss in the end. Some levels feature "death drops" where the player must avoid falling, while throwing enemies there at the same time, including a typical elevator level.  Several items are scattered on the ground, from melee weapons and bonus points (and lives or additional police cars) to apples and turkeys (to restore health).</desc>
		<rating>0.8</rating>
		<releasedate>19910701T000000</releasedate>
		<developer>SEGA</developer>
		<publisher>SEGA</publisher>
		<genre>Beat'em Up</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Streets of Rage 2 (U) [!].zip</path>
		<name>Streets of Rage 2</name>
		<desc>After Axel Stone, Blaze Fielding and Adam Hunter destroyed the evil Syndicate leader, Mr. X, the city became a peaceful place to live, and each one of them followed their own paths. One year later, after their reunion, Adam's brother Sammy returned from school to find their apartment in a mess, and Adam nowhere to be seen, and after calling his two friends, one of them notices a photo of Adam chained to a wall, next to someone they knew very well - Mr. X, who returned to turn the peaceful city once again into a war zone. Now, Axel, Blaze, Sammy, and Axel's good friend Max, a pro wrestler, must head out to stop Mr. X once again...hopefully for good...

Streets of Rage 2 differs from the previous title in several ways. There are changes in both graphics (characters now are bigger, more detailed and with more animation frames, and scenarios are less grainy) and gameplay (the rocket move was replaced by a special move that doubles in offense and defense along several new moves), along other new features such as life bars (and names) for all enemies and the radically different new characters.</desc>
		<rating>0.8</rating>
		<releasedate>19921201T000000</releasedate>
		<developer>SEGA</developer>
		<publisher>SEGA</publisher>
		<genre>Beat'em Up</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Streets of Rage 3 (E).zip</path>
		<name>Streets of Rage 3</name>
		<desc>Streets of Rage 3 aimed to build on the success of its predecessor, so while the style of gameplay and control scheme is largely identical to its predecessors, significant changes were made to the overall structure of the game. Streets of Rage 3 is a faster paced release with longer levels, a more complex plot (which in turn leads to more in-depth scenarios complete with interactive levels and multiple endings) and the return of traps such as pits. Dash and dodge moves were added to each character's arsenal of moves, and weapons can now only be used for a few times before breaking.

Changes to the fighting mechanics allows for the integration of weapons with certain movesets. Team attacks, absent from Streets of Rage 2 but available in the original Streets of Rage, make a return, and are occasionally used by enemies too. Blitz moves, performed while running, have also been altered and are now upgradable over the course of the game (predicated on how many points are earned per level). Death causes a downgrade, however holding the X button before a series of button combinations can give players access to the upgraded moveset at any point in the game, at the expense of the time taken to perform attacks.

Enemies are also smarter with weapons, and some can even steal health upgrades, and there are also several secret playable characters, unlockable after overcoming certain conditions during the game. Special moves also no longer drain the user's health - a separate, automatically regenerating bar is introduced for this purpose.</desc>
		<rating>0.8</rating>
		<releasedate>19940317T000000</releasedate>
		<developer>SEGA</developer>
		<publisher>SEGA</publisher>
		<genre>Beat'em Up</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Super Street Fighter II - The New Challengers (U) [b1].zip</path>
		<name>Super Street Fighter II</name>
		<desc>This is the sequel to the super hit Street Fighter II Turbo and Street Fighter II Championship games for the SNES and Genesis. This port of the arcade game featured all 4 new characters and stages making a total of 16 playable. The game was packed into massive 32Meg and 40Meg cartridges for the SNES and Genesis. Featured many multiplayer modes in addition to the single player mode. There was the returning elimination group battle where you and a group of people played until one person was the champ. The Point Battle where the person with the most points wins. Newer modes included Tournament where you had an 8 man double elimination tournament. Finally the Challenge mode, where you tried to get the most points on a CPU opponent or beat them real fast trying to surpass records.
</desc>
		<rating>0.9</rating>
		<releasedate>19940101T000000</releasedate>
		<developer>Capcom</developer>
		<publisher>Capcom</publisher>
		<genre>Fighting</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Ultimate Mortal Kombat 3 (UE).zip</path>
		<name>Ultimate Mortal Kombat 3</name>
		<desc>Ultimate Mortal Kombat 3 combines the best of all the Mortal Kombats into a single cartridge. 23 playable characters are immediately available, such as Reptile, Cyrax, Scorpion, Sub-Zero, Jax, Katana, Sonya, and more. There are two bosses that are unlockable, as well as additional characters.

There is a variety of new levels, some of which are interactive. Characters can uppercut someone, causing them to hit the ground hard and crash through to the bottom floor, or they can knocked someone off a bridge, landing in a pit of spikes.

Players can go against the computer one-on-one, two-on-two, or take part in the 8-fighter tournament.

The DS version has a wireless one-one-one multiplayer mode and includes the Puzzle Kombat mini-game from Mortal Kombat: Deception.</desc>
		<rating>0.7</rating>
		<releasedate>19960101T000000</releasedate>
		<developer>Midway</developer>
		<publisher>Acclaim</publisher>
		<genre>Fighting</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Vectorman (U).zip</path>
		<name>Vectorman</name>
		<desc>In 2049, the human population of Earth embarks on a migratory voyage to try to colonize other planets. They leave mechanical "orbots" to clean up the mess they made on Earth through littering and pollution. Raster, a high-level orbot who watches Earth through a planetwide computer network, is accidentally attached to a working nuclear missile by a lesser orbot and goes insane, becoming an evil dictator named Warhead. He declares himself ruler of Earth, and begins preparing to execute any humans who dare return to their planet.

Enter Vectorman, a humble robot in charge of cleaning up toxic sludge by simply discharging it into the sun. As he lands on Earth after his last trip, he finds chaos and confusion. Because all the other Orbots are controlled by Warhead (Vectorman having not been affected because he was away), Vectorman takes it upon himself to destroy the errant orbot and restore peace to Earth.</desc>
		<rating>0.8</rating>
		<releasedate>19951024T000000</releasedate>
		<developer>BlueSky Software</developer>
		<publisher>SEGA</publisher>
		<genre>Platform</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Vectorman 2 (U).zip</path>
		<name>Vectorman 2</name>
		<desc>This is a sequel to  Vectorman. This time, the super-powerful little robot was attacked while coming back to earth in his spaceship. He falls down on the earth only to discover dark locations full of hostile creatures and to participate in a platformer full of fast and furious action. Fight your enemies, collect photons, jump over obstacles, find weapons, morph into other creatures, and climb walls as the green "orbot" Vectorman.</desc>
		<rating>0.9</rating>
		<releasedate>19961115T000000</releasedate>
		<developer>BlueSky Software</developer>
		<publisher>SEGA</publisher>
		<genre>Platform</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Castlevania - The New Generation (E) [!].zip</path>
		<name>Castlevania: The New Generation</name>
		<desc>In the year 1917, evil had threatened to rise up again in Transylvania. A young lady named Elizabeth Bartley, who was tried as a witch and killed centuries before, was planning to resurrect the Prince of Darkness, Count Dracula, once again.

The latest of the Belmont lineage, John Morris, and his friend Eric Lecarde, must now travel across Europe to the Palace of Versailles in France, where Bartley is planning the resurrection. And in their way stands Dracula's strongest followers yet...</desc>
		<rating>0.9</rating>
		<releasedate>19940320T000000</releasedate>
		<developer>Konami</developer>
		<publisher>Konami</publisher>
		<genre>Action, Platform</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Spider-Man . Venom - Maximum Carnage (World).md</path>
		<name>Spider-Man &amp; Venom : Maximum Carnage</name>
		<desc>Loosely based on the comic book series, the story opens as Carnage breaks out of the insane asylum and wreaks mayhem. Spiderman immediately acknowledges the new job at hand and sets out to stop him.

You start off with Spidey but in certain parts you get to choose between him and Venom, which takes you through an alternate routes. The gameplay is your standard beat-em-up, the regular punching and jump-kicking, with the addition of the all important webbing - ie web swinging, web shield etc.
</desc>
		<rating>0.7</rating>
		<releasedate>19940801T000000</releasedate>
		<developer>Software Creations</developer>
		<publisher>Acclaim</publisher>
		<genre>Beat'em Up</genre>
		<players>1</players>
	</game>
</gameList>
''';

const _gamelistPs2 = '''
<?xml version="1.0"?>
<alternativeEmulator>
	<label>PCSX2 (Standalone)</label>
</alternativeEmulator>
<gameList>
	<folder>
		<path>./Crash Bandicoot - The Wrath of Cortex (USA) (v1.01)</path>
		<name>Crash Bandicoot : The Wrath of Cortex</name>
		<desc>Crash Bandicoot: The Wrath of Cortex is the first Crash Bandicoot game for a system other than the original PlayStation. The story is set some time after Warped: Dr. Cortex wants revenge after being defeated by Crash (again). For this purpose, he creates Crunch, a super-bandicoot who can destroy everything that crosses his way. So Crash needs to defeat Crunch (and in the end, Dr. Cortex).

The game is a typical jump and run, with some other action passages, like air combat and a sequence where Crash is trapped inside a giant sphere rolling around in some sort of rollercoaster. All graphics are in 3D, and the sound is typical for cartoon games like this. The whole game is pretty straightforward in design, getting stuck on a puzzle is not really possible.</desc>
		<rating>0.8</rating>
		<releasedate>20011101T000000</releasedate>
		<developer>Traveller's Tales</developer>
		<publisher>Universal Interactive</publisher>
		<genre>Platform</genre>
		<players>1</players>
	</folder>
	<game>
		<path>./Crash Bandicoot - The Wrath of Cortex (USA) (v1.01)/Crash Bandicoot - The Wrath of Cortex (USA) (v1.01).bin</path>
		<name>Crash Bandicoot : The Wrath of Cortex</name>
		<desc>Crash Bandicoot: The Wrath of Cortex is the first Crash Bandicoot game for a system other than the original PlayStation. The story is set some time after Warped: Dr. Cortex wants revenge after being defeated by Crash (again). For this purpose, he creates Crunch, a super-bandicoot who can destroy everything that crosses his way. So Crash needs to defeat Crunch (and in the end, Dr. Cortex).

The game is a typical jump and run, with some other action passages, like air combat and a sequence where Crash is trapped inside a giant sphere rolling around in some sort of rollercoaster. All graphics are in 3D, and the sound is typical for cartoon games like this. The whole game is pretty straightforward in design, getting stuck on a puzzle is not really possible.</desc>
		<rating>0.8</rating>
		<releasedate>20011101T000000</releasedate>
		<developer>Traveller's Tales</developer>
		<publisher>Universal Interactive</publisher>
		<genre>Platform</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Bully (USA).iso</path>
		<name>Bully</name>
		<desc>Bully is a subtle sandbox game set in a school environment. The player takes control of teenage rebel James "Jimmy" Hopkins, who from the opening cutscene is revealed to be a difficult student with a disruptive background. The game concerns the events that follow Jimmy being dropped off at Bullworth Academy, a fictional New England boarding school. The player is free to explore the school campus in the beginning and, later on in the game, the town, or to complete the main missions. The game makes extensive use of minigames. Some are used to earn money, others to improve Jimmy's abilities or get new items.

School classes themselves are done in the form of minigames, broken into five levels of increasing difficulty. Each completed class brings a benefit to gameplay. English, as an example, is a word scramble minigame, and as Jimmy does well in this minigame, he learns various language-skills, such as the ability to apologize to police for small crimes. Chemistry also an example, is a button pushing minigame, and if Jimmy does well, he gains the ability to create firecrackers, stink bombs, and other items at his chemistry set in his room at the dorm.</desc>
		<rating>0.9</rating>
		<releasedate>20061017T000000</releasedate>
		<developer>Rockstar Games</developer>
		<publisher>Rockstar Games</publisher>
		<genre>Adventure</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Crash Twinsanity (USA) (v2.00).iso</path>
		<name>Crash Twinsanity</name>
		<desc>Two purple birds called the Evil Twins form a new threat to Crash's homeworld. Crash has to team up with his arch rival Dr. Neo Cortex to put a stop to this new threat.

Crash Twinsanity is a classic-style Crash platform game, though this time Crash has to work together with Dr. Cortex from time to time. Crash can pick up and throw Dr. Cortex to places he can't reach himself, or use him as a hammer to slap enemies. The consistent conflict between both heroes causes many funny situations.</desc>
		<rating>0.8</rating>
		<releasedate>20040926T000000</releasedate>
		<developer>Traveller's Tales</developer>
		<publisher>Sierra</publisher>
		<genre>Platform</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Digimon Rumble Arena 2 (USA).iso</path>
		<name>Digimon Rumble Arena 2</name>
		<desc>Bandai's follow-up to its 2002 game on PlayStation offers PS2 owners four-player action and a total of 49 characters from the first four seasons of the Digimon television series. Single-player fighting involves advancing through a series of 3D opponents and high-powered boss encounters, while multiplayer competition has up to four players competing simultaneously on the same screen. As in the original game, the battle arenas offer distinct hazards and obstacles to avoid while challenging rivals.</desc>
		<rating>0.7</rating>
		<releasedate>20040903T000000</releasedate>
		<developer>Black Ship Games</developer>
		<publisher>Bandai</publisher>
		<genre>Fighting</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./FIFA Street 2 (USA) (En,Es).iso</path>
		<name>FIFA Street 2</name>
		<desc>FIFA Street 2 is second installment in EA's four-on-four soccer game. FIFA Street 2 will feature improved controls, many more tricks, and a new juggle mechanic. Take part in game modes, such as friendly, rule the street, and skills challenge. Choose from 20 national teams and 300-plus real-life soccer stars. There are 10 playable venues ranging from London's Westway Leisure Center to the sandy beaches of Brazil.</desc>
		<rating>0.9</rating>
		<releasedate>20060228T000000</releasedate>
		<developer>Electronic Arts</developer>
		<publisher>EA Sports BIG</publisher>
		<genre>Sports / Football (Soccer)</genre>
		<players>2-4</players>
	</game>
	<game>
		<path>./Gran Turismo 3 - A-Spec (USA) (v1.10).iso</path>
		<name>Gran Turismo 3 : A-spec</name>
		<desc>The third game in the Gran Turismo series of racing games for PlayStation and PlayStation 2.

This time with an even more realistic driving experience. Lighting now has an effect on the game, such as buildings blocking the sunlight. There are now smoke effects caused by skidding. Now there is even heat rising from the road.</desc>
		<rating>0.9</rating>
		<releasedate>20010709T000000</releasedate>
		<developer>Polyphony Digital</developer>
		<publisher>Sony Computer Entertainment</publisher>
		<genre>Racing, Driving</genre>
		<players>1-6</players>
	</game>
	<game>
		<path>./Grand Theft Auto - Liberty City Stories (USA).iso</path>
		<name>Grand Theft Auto : Liberty City Stories</name>
		<desc>There are a million stories in Liberty City. This one changes everything. Once a trusted wise guy in the Leone crime family, Toni Cipriani was forced into hiding after killing a made man. Now he's back and it's time for things to be put right.

The streets of Liberty City are in turmoil. Warring mafiosi vie for control as the town begins to self-destruct under waves of political corruption, organized crime, drug trafficking and union strikes. No one can be trusted as Toni tries to clean up the mess of the city's chaotic underworld. Deranged hit men, morally depraved tycoons, cynical politicians and his own mother stand in his way as Toni tries to bring the city under Leone control.

Forced to fight for his life in an odyssey that will shake Liberty City to its foundations, Toni must use any means necessary to secure his place in the leadership of the Leone family in a town up for grabs.</desc>
		<rating>0.8</rating>
		<releasedate>20060606T000000</releasedate>
		<developer>Rockstar Leeds</developer>
		<publisher>Rockstar Games</publisher>
		<genre>Racing, Driving</genre>
		<players>1</players>
	</game>
	<game>
		<path>./LEGO Batman - The Videogame (USA).iso</path>
		<name>LEGO Batman : The Videogame</name>
		<desc>Continuing the tradition of adapting known franchises such as Star Wars and Indiana Jones with visuals based on LEGO, this game takes on the Batman universe. The basic concept is the same, with characters and objects built up using LEGO blocks, but here shown against surroundings drawn in a regular fashion. Most of the environments are side-scrolling with a fixed camera perspective, but in 3D with quite some depth. 
 The Dynamic Duo hits the bricks in LEGO Batman: The Videogame. In the game's main campaign, players take control of Batman and Robin for familiar bust-and-build action and puzzle-solving adventure through more than a dozen levels of Gotham City -- re-created completely from Lego brand toy building blocks, of course. </desc>
		<rating>0.9</rating>
		<releasedate>20080923T000000</releasedate>
		<developer>Traveller's Tales</developer>
		<publisher>Warner Bros. Games</publisher>
		<genre>Platform</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Midnight Club 3 - DUB Edition Remix (USA).iso</path>
		<name>Midnight Club 3 : DUB Edition Remix</name>
		<desc>Midnight Club 3: DUB Edition Remix is an update to Midnight Club 3: DUB Edition. It is available as a Greatest Hits release on PlayStation 2. It was released on March 12, 2006 or exactly eleven months after the original version's release. It was released on December 19, 2012 on PlayStation Network. However, it was removed after a passing of time due to licensing issues.
The game features all of the cities, vehicles, and music from Midnight Club 3: DUB Edition. This version of the game also allows the player to import the Midnight Club 3: DUB Edition data on their memory card to Midnight Club 3: DUB Edition Remix to make up for lost progress, thus saving the player from starting all over again.</desc>
		<rating>1</rating>
		<releasedate>20060313T000000</releasedate>
		<developer>Rockstar Games</developer>
		<publisher>Rockstar Games</publisher>
		<genre>Racing, Driving</genre>
		<players>1-8</players>
	</game>
	<game>
		<path>./Need for Speed - Carbon (USA).iso</path>
		<name>Need for Speed : Carbon</name>
		<desc>The gameplay is based upon rival street racing crews. Players run a crew and can hire specific street racers to be in their crew and the active friendly racer is known as a wingman. Each hirable street racer has two skills, one which is a racing skill (scout, blocker, and drafter) and a non-race skill (fixer, mechanic, and fabricator). Each skill has different properties from finding hidden alleys/back streets (shortcuts) to reducing police attention. Cars driven by the wingmen are also different; blockers drive muscles, drafters drive exotics and scouts drive tuners (although the first two unlockable wingmen (Neville and Sal) drive cars according to the player's chosen car class at the start of the game). In career mode, players have to race tracks and win to conquer territories and face off against bosses to conquer districts.</desc>
		<rating>0.8</rating>
		<releasedate>20061031T000000</releasedate>
		<developer>Electronic Arts</developer>
		<publisher>EA Games</publisher>
		<genre>Racing, Driving</genre>
		<players>2</players>
	</game>
	<game>
		<path>./Need for Speed - Underground 2 (USA).iso</path>
		<name>Need for Speed : Underground 2</name>
		<desc>Need For Speed Underground 2 takes place in Bayview after the events of Need for Speed: Underground. The prologue begins with the player driving in a Nissan Skyline R34 in Olympic City (though the racing scenes are actually in Bayview), the setting of NFS:UG. He then receives a race challenge from a rather ominous personality who offers him a spot on his crew, but "won't take 'no' for an answer." The player races off â€” despite Samantha's warnings â€” only to be ambushed by a mysterious driver in a rage that totals his Skyline. The driver, who has a unique scythe tattoo, makes a call confirming the accident, and the flashback fades out.</desc>
		<rating>0.9</rating>
		<releasedate>20041115T000000</releasedate>
		<developer>Electronic Arts</developer>
		<publisher>Electronic Arts</publisher>
		<genre>Racing, Driving</genre>
		<players>2-6</players>
	</game>
	<game>
		<path>./Sonic Unleashed (USA) (En,Ja,Fr,De,Es,It).iso</path>
		<name>Sonic Unleashed</name>
		<desc>Gameplay in Sonic Unleashed focuses on two modes of platforming play: fast-paced levels that take place during daytime, showcasing Sonic's trademark speed as seen in previous games in the series, and slower, night-time levels, during which Sonic's Werehog form emerges, and gameplay switches to an action-based, brawler style of play, in which Sonic battles Gaia enemies</desc>
		<rating>0.8</rating>
		<releasedate>20081118T000000</releasedate>
		<developer>SEGA</developer>
		<publisher>Sonic Team</publisher>
		<genre>Beat'em Up</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Need for Speed - Most Wanted - Black Edition (USA).iso</path>
		<name>Need for Speed : Most Wanted</name>
		<desc>The player arrives in Rockport City, driving a racing version of the BMW M3 GTR (E46). Following Mia Townsend (played by Josie Maran), the player proves his driving prowess as he is pursued by a veteran police officer named Sergeant Cross (played by Dean McKenzie), who vows to take down the player and end street racing in Rockport.
Races seem to be in the player's favor until a particular group of racers, led by the game's antagonist, Clarence "Razor" Callahan (played by Derek Hamilton), sabotages and win the player's car in a race.

Without a car to escape in, the player is arrested by Cross, but is later released due to lack of evidence. Mia picks up the player and then informs the player about Razor's new status on the Blacklist, a group of 15 drivers most wanted by the Rockport Police Department. She then helps by assisting the player in acquiring a new car and working his way up the Blacklist. Rivals are defeated one by one, and the player is rewarded with reputation, new rides, and ride improvements with every Blacklist member taken down. 
As new boroughs are opened up throughout Rockport (Rosewood, Camden Beach, and Downtown Rockport), Mia also sets up safehouses for the player to lie low in, in exchange for placement of "side bets" on the player's races.</desc>
		<rating>0.9</rating>
		<releasedate>20051115T000000</releasedate>
		<developer>EA Canada</developer>
		<publisher>Electronic Arts</publisher>
		<genre>Racing, Driving</genre>
		<players>2</players>
		<favorite>true</favorite>
	</game>
	<game>
		<path>./Tony Hawk's Underground 2 (USA).iso</path>
		<name>Tony Hawk's Underground 2</name>
		<desc>The gameplay in Tony Hawk's Underground 2 is similar to that of previous Tony Hawk games: the player skates around in a 3D environment modeled after various cities and attempts to complete various goals. Most goals involve skating on or over various objects or performing combos. Scores are calculated by adding the sum of the point value of each trick strung together in a combo and then multiplying by the number of tricks in the combo</desc>
		<rating>0.9</rating>
		<releasedate>20041004T000000</releasedate>
		<developer>Neversoft</developer>
		<publisher>Activision</publisher>
		<genre>Sports</genre>
		<players>2</players>
		<favorite>true</favorite>
	</game>
	<game>
		<path>./LEGO Batman 2 - DC Super Heroes (USA) (En,Fr,Es,Pt).nkit.iso</path>
		<name>LEGO Batman 2 - DC Super Heroes (USA) (En,Fr,Es,Pt).nkit</name>
		<playcount>1</playcount>
		<lastplayed>20241207T153705</lastplayed>
	</game>
	<game>
		<path>./Crash Bandicoot - The Wrath of Cortex (USA) (v1.01).bin</path>
		<name>Crash Bandicoot : The Wrath of Cortex</name>
		<desc>Crash Bandicoot: The Wrath of Cortex is the first Crash Bandicoot game for a system other than the original PlayStation. The story is set some time after Warped: Dr. Cortex wants revenge after being defeated by Crash (again). For this purpose, he creates Crunch, a super-bandicoot who can destroy everything that crosses his way. So Crash needs to defeat Crunch (and in the end, Dr. Cortex).

The game is a typical jump and run, with some other action passages, like air combat and a sequence where Crash is trapped inside a giant sphere rolling around in some sort of rollercoaster. All graphics are in 3D, and the sound is typical for cartoon games like this. The whole game is pretty straightforward in design, getting stuck on a puzzle is not really possible.</desc>
		<rating>0.8</rating>
		<releasedate>20011101T000000</releasedate>
		<developer>Traveller's Tales</developer>
		<publisher>Universal Interactive</publisher>
		<genre>Platform</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Dragon Ball Z - Infinite World (USA).iso</path>
		<name>Dragon Ball Z : Infinite World</name>
		<desc>This is a fighting game in the Dragon Ball franchise.
You can choose over 40 different characters from the Dragon Ball Z (and even GT) series.
Over 130 missions to choose from in Dragon Missions mode (essentially a story mode)
100 transformations to unlock and 25 different battle stages.
</desc>
		<rating>0.7</rating>
		<releasedate>20081204T000000</releasedate>
		<developer>Dimps</developer>
		<publisher>Bandai</publisher>
		<genre>Fighting</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Burnout Revenge (USA).chd</path>
		<name>Burnout Revenge</name>
		<desc>In Burnout Revenge, players compete in a range of racing game types with different aims. These take place within rush-hour traffic, and include circuit racing, Road Rage (where players cause as many rivals to crash as possible within a time limit, or until the player's car is wrecked), Burning Lap (a single-lap, single-racer time attack mode), Eliminator (a circuit race where every thirty seconds, the last-placed racer's car is detonated; the race continues until only one racer is left), and Crash (where the player is placed at a junction with the aim of accumulating as many "Crash Dollars" as possible). A new gameplay feature in Burnout Revenge is the ability to ram same-way small to medium traffic, known as "traffic checking", propelling the rammed car forward; the event in which a "checked" car hits a rival is considered as a Traffic Takedown. Traffic checking is the focus of a new race type, Traffic Attack (whereby a player must earn a set amount of Crash Dollars through checking traffic), which can be used later on.</desc>
		<rating>0.9</rating>
		<releasedate>20050913T000000</releasedate>
		<developer>Criterion Games</developer>
		<publisher>Electronic Arts</publisher>
		<genre>Racing, Driving</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Gran Turismo 4.iso</path>
		<name>Gran Turismo 4</name>
		<desc>GT4 continues in its predecessors' footsteps by offering an extremely large list of cars; the PAL version features 721 cars from 80 manufacturers. 

Players now accumulate points by winning races in the normal first-person driving mode, called A-Spec mode. Each race event can yield up to a maximum of 200 A-Spec points. Generally, a win using a car with less of an advantage over the AI opponents is worth more points. Points can only be won once, so to win further points from a previously-won event, it must be re-won using a car with less of an advantage over the AI. There are also the 34 Missions which can yield 250 points each. Despite this, A-Spec points are experience points, not money.</desc>
		<rating>0.9</rating>
		<releasedate>20050222T000000</releasedate>
		<developer>Polyphony Digital</developer>
		<publisher>Sony Computer Entertainment</publisher>
		<genre>Racing, Driving</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Metal Gear Solid 3 - Snake Eater [PS2][FULLDVD][Multi2][www.pctorrent.com].iso</path>
		<name>Metal Gear Solid 3 : Snake Eater</name>
		<desc>Hideo Kojima's critically acclaimed "tactical espionage action" series returns to PlayStation 2 in the anticipated follow-up to 2001's Sons of Liberty. Instead of slinking around futuristic installations, knocking on metal to distract guards, or crawling underneath a cardboard box, players are given a whole new Snake to wrangle. Drawing its inspiration from films like First Blood and Rambo: First Blood Part II, Snake Eater drops players in the middle of a thick jungle teeming with wildlife and, of course, terrorists.
 Heavily armed enemies dressed in camouflage gear will patrol the dense forests, waterfalls, and surrounding areas, so players will be able to climb trees, fire pistols while hanging down from branches, and crawl through hollowed out logs to stalk their prey. Along the way, Snake will have to find sustenance by catching fish or other wildlife, while being mindful of natural hazards such hornets nests, cliffs, and rapids. Metal Gear Solid 3: Snake Eater was first revealed in a 12-minute preview displayed at 2003's E3 in Los Angeles, California.
</desc>
		<rating>1</rating>
		<releasedate>20041117T000000</releasedate>
		<developer>Konami</developer>
		<publisher>Konami</publisher>
		<genre>Adventure</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Ratchet &amp; Clank.iso</path>
		<name>Ratchet &amp; Clank</name>
		<desc>Ratchet &amp; Clank  involves the two protagonists Ratchet, a furry alien creature, and Clank, a nerdy little robot, going on a quest to find Captain Qwark and ultimately to help save the galaxy.
Firstly each of the game's levels are huge sweeping vistas with extremely detailed buildings which are visible at all times. This means that a building on the horizon is not just a backdrop; in all likelihood Ratchet will be exploring it in a few moments time. Secondly, the game includes a number of sub-games, such as a space fight sequence and a number of turret shoot-outs which are akin to Missile Command in the first person.
The game has over twenty levels and includes as many real-time cut-scenes which tell the story. The story is non-linear, requiring the player to return to previous levels to complete objectives and to choose between multiple paths forward. There is also a respectable array of weapons, gadgets, and accessories to find or buy as the game progresses.</desc>
		<rating>0.9</rating>
		<releasedate>20021104T000000</releasedate>
		<developer>Insomniac Games</developer>
		<publisher>Sony Computer Entertainment</publisher>
		<genre>Platform</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Ratchet &amp; Clank Size Matters.iso</path>
		<name>Ratchet &amp; Clank : Size Matters</name>
		<desc>While on a much needed vacation, Ratchet and Clank's rest and relaxation time is suddenly cut short as they soon find themselves lured into a mysterious quest. Following the trail of a kidnapped girl, Ratchet and Clank rediscover a forgotten race of genius inventors known as the Technomites. They soon uncover a plot more dangerous than they could have imagined.</desc>
		<rating>0.6</rating>
		<releasedate>20080213T000000</releasedate>
		<developer>High Impact Games</developer>
		<publisher>Sony Computer Entertainment</publisher>
		<genre>Platform</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Ratchet &amp; Clank 3 Up Your Arsenal.iso</path>
		<name>Ratchet &amp; Clank : Up Your Arsenal</name>
		<desc>In Ratchet &amp; Clank: Up Your Arsenal, Ratchet and Clank once again team up for an all-new adventure that combines diverse gameplay with elements of action, exploration, adventure, puzzle-solving, strategy, and role-playing into one experience. Together with the Q-Force, Ratchet and Clank set off to uncover the schemes of the sinister Dr. Nefarious and keep the galaxy safe for organic life. As one of three characters, you can now wield new weapons and gadgets, gain access to an array of vehicles, and master all-new abilities. The game also features both single-player and multiplayer (offline and online) gameplay.</desc>
		<rating>0.9</rating>
		<releasedate>20041109T000000</releasedate>
		<developer>Insomniac Games</developer>
		<publisher>Sony Computer Entertainment</publisher>
		<genre>Platform</genre>
		<players>1-8</players>
	</game>
	<game>
		<path>./Ratchet &amp; Clank 2 Going Commando.iso</path>
		<name>Ratchet &amp; Clank : Going Commando</name>
		<desc>From the creators of Ratchet &amp; Clank comes the next installment of this sci-fi action adventure series. Ratchet &amp; Clank: Going Commando features more than 50 imaginative weapons and gadgets. The more things you blow up, the stronger Ratchet gets and the more advanced the weapons you'll have. Participate in all-new side challenges; destroy hordes of enemies in gladiator arenas, upgrade your ship and pick off enemies in space combat, and leave competitors to eat your dust in hi-speed challenge. Are you up for it?</desc>
		<rating>0.9</rating>
		<releasedate>20031111T000000</releasedate>
		<developer>Insomniac Games</developer>
		<publisher>Sony Computer Entertainment</publisher>
		<genre>Platform</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Ratchet &amp; Clank Gladiator.iso</path>
		<name>Ratchet : Deadlocked</name>
		<desc>Ratchet: Deadlocked is the fourth game in the Ratchet &amp; Clank series by Insomniac Games. The storyline involves Ratchet and Clank, along with Al, being kidnapped and forced to compete in a underground reality show called "DreadZone" run by the media mogul Gleeman Vox on the outer fringes of the galaxy. 

The game differs from its predecessors in that it focuses more on shooting than platforming and puzzle elements. The game allows you to use two bots to fight along side you, which can be upgraded over time with better weapons and firepower. There is a total of  10 weapons in the game, significantly less than the other games. However, modding these weapons is more emphasized than before, with different kinds of Alpha and Omega mods. Omega mods can be used on any weapon, and range from the freeze mod to the magma mod. Alpha mods are weapon-specific, and increase the rate of fire, ammo capacity, and power. The game also features online multiplayer.

Clank is not a playable character in this game, although he gives advice to Ratchet over his communication link.</desc>
		<rating>0.9</rating>
		<releasedate>20051025T000000</releasedate>
		<developer>Insomniac Games</developer>
		<publisher>Sony Computer Entertainment</publisher>
		<genre>Action</genre>
		<players>1-4</players>
	</game>
	<game>
		<path>./Warriors, The (USA) (EnFrDeEsIt).chd</path>
		<name>The Warriors</name>
		<desc>The Warriors is an action game for Playstation 2. You play as various members of the Warriors gang wrongly accused of having killed a rival geng member. It's up to you to make your law reign, that of weapons and force.</desc>
		<rating>0.9</rating>
		<releasedate>20051017T000000</releasedate>
		<developer>Rockstar Games</developer>
		<publisher>Take 2 Interactive</publisher>
		<genre>Beat'em Up</genre>
		<players>2</players>
	</game>
	<game>
		<path>./Grand Theft Auto - Vice City (USA) (v3.00).chd</path>
		<name>Grand Theft Auto : Vice City</name>
		<desc>The player takes on the role of Tommy Vercetti, a man who was released from prison in 1986 after serving 15 years for killing eleven people. The leader of the organization for whom he used to work, Sonny Forelli, fears that Tommy's presence in Liberty City will heighten tensions and bring unwanted attention upon his organization's criminal activities. To prevent this, Sonny ostensibly "promotes" Tommy and sends him to Vice City to act as their buyer for a series of cocaine deals.[7] During Tommy's first meeting with the drug dealers, an ambush by an unknown party results in the death of Tommy's bodyguards, Harry and Lee, and the cocaine dealer. There is another survivor, the pilot of the dealer's helicopter, who flies off and escapes. Tommy narrowly escapes with his life, but he loses both the Forelli's money and the cocaine.</desc>
		<rating>0.9</rating>
		<releasedate>20021027T000000</releasedate>
		<developer>Rockstar North</developer>
		<publisher>Rockstar Games</publisher>
		<genre>Racing, Driving</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Mafia (USA).chd</path>
		<name>Mafia</name>
		<desc>Mafia is set in the 1930s, between the fall of 1930 through to the end of 1938, during the later part of Prohibition, which ended in 1933. The game is set in the fictional American city of Lost Heaven (loosely based on New York City and Chicago of the same time period).

The player takes the role of taxi driver Thomas "Tommy" Angelo, who, while trying to make a living on the streets of Lost Heaven, unexpectedly and unwillingly becomes involved in organized crime as a driver and enforcer for the Salieri crime family, led by Don Ennio Salieri.

Through the events of the game's story, Tommy begins to rise through the ranks of the Salieri family, which is currently battling the competing Morello family, led by the sharply-dressed Don Morello. Eventually becoming disillusioned by his life of crime and violence, Tommy arranges to meet a detective (Detective Norman) in order to tell him his story, to be given witness protection, and to aid the detective in the destruction of the Salieri crime family. The 'Intermezzo' chapters of the game depict Tommy sitting in a cafe with the detective, relating his life story and giving out important pieces of information at the same time.</desc>
		<rating>0.7</rating>
		<releasedate>20040128T000000</releasedate>
		<developer>Illusion Softworks</developer>
		<publisher>Gathering</publisher>
		<genre>Adventure</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Star Wars - The Force Unleashed (USA) (EnFr).chd</path>
		<name>Star Wars : The Force Unleashed</name>
		<desc>The game bridges the two Star Wars trilogies and introduces a new protagonist, code named "Starkiller", as Darth Vader's secret apprentice.</desc>
		<rating>0.8</rating>
		<releasedate>20080916T000000</releasedate>
		<developer>LucasArts</developer>
		<publisher>Krome</publisher>
		<genre>Action / Adventure</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Mortal Kombat - Deadly Alliance (USA).chd</path>
		<name>Mortal Kombat : Deadly Alliance</name>
		<desc>The fifth Mortal Kombat fighting game is the first to be designed exclusively for home consoles instead of the arcades. The game features a new 3D engine to support the familiar combination of weapon and hand-to-hand combat, but moves are now based on real-life martial arts styles, such as Crane, Snake, Tai Chi, Tae Kwon Do, Muay Thai, Tang Soo Doo, and more. Fighting styles can be switched at any time during a match, and the damage a character receives will be visible on his or her face, body, clothing, or movements.



 Returning characters from the best-selling series include Scorpion, Sub-Zero, Cyrax, Jax, Raiden, Sonya, Kitana, Shang Tsung, Quan Chi, and Reptile. Characters making their debut in Deadly Alliance include a female counterpart for Sub-Zero, a blind samurai, and a masked tribal warrior. Arenas take place in fully 3D environments, fraught with spiked pits, pools of acid, and other deadly hazards. New special moves and gruesome fatalities will also be included as the franchise makes its debut on the next-generation systems.
 </desc>
		<rating>0.8</rating>
		<releasedate>20021118T000000</releasedate>
		<developer>Midway</developer>
		<publisher>Midway</publisher>
		<genre>Fighting</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Mortal Kombat - Deception (USA) (Premium Pack Bonus Disc).chd</path>
		<name>Mortal Kombat : Deception</name>
		<desc>Twenty-six characters are available to play in the game, with nine making their first appearance in the series. Deception contains several new features in the series, such as chess and puzzle games with the MK characters and an online mode. The Konquest Mode role-playing game (RPG) makes a return from Deadly Alliance, but follows the life of Shujinko, a warrior who is deceived by Onaga to search for artifacts to give Onaga more powers. In November 2006, Midway released Mortal Kombat: Unchained, a port for the PlayStation Portable, which adds new characters to the game.</desc>
		<rating>0.9</rating>
		<releasedate>20041004T000000</releasedate>
		<developer>Midway</developer>
		<publisher>Midway</publisher>
		<genre>Fighting</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Tom Clancys Splinter Cell (USA).chd</path>
		<name>Tom Clancy's Splinter Cell</name>
		<desc>Set in the fall of 2004, the player takes on the role of Sam Fisher, a long-dormant secret agent called back to duty by the American National Security Agency, to work with a secret division dubbed "Third Echelon". At this point, Fisher hasn't "been in the field in years". Fisher must investigate the disappearance of two CIA agents in the country of Georgia, which soon leads to a larger mission: saving the world from war with Georgia.</desc>
		<rating>0.9</rating>
		<releasedate>20030408T000000</releasedate>
		<developer>Ubisoft</developer>
		<publisher>Ubisoft</publisher>
		<genre>Action</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Tom Clancys Splinter Cell - Chaos Theory (Europe) (EnEsIt).chd</path>
		<name>Tom Clancy's Splinter Cell : Chaos Theory</name>
		<desc>The game follows the covert activities of Sam Fisher, an agent working for a black-ops branch within the NSA called "Third Echelon".</desc>
		<rating>0.9</rating>
		<releasedate>20050328T000000</releasedate>
		<developer>Ubisoft</developer>
		<publisher>Ubisoft</publisher>
		<genre>Action</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Tom Clancys Splinter Cell - Double Agent (Europe) (EnEsIt).chd</path>
		<name>Tom Clancy's Splinter Cell : Double Agent</name>
		<desc>Shortly after the events of Chaos Theory, Sam Fisher must deal with the recent loss of his daughter to a drunk driving accident. But he has little time to mourn, he soon has to go on an undercover assignment which requires him to pose as a criminal in order to infiltrate a terrorist group based in the United States. This new mission forces Fisher into a new and very dangerous gray area, where the line between right and wrong is blurred even beyond what Fisher is used to, and thousands of innocent lives are in the balance.

 The Playstation 2 version features offline-only two agent co-op missions.</desc>
		<rating>0.9</rating>
		<releasedate>20061024T000000</releasedate>
		<developer>Ubisoft</developer>
		<publisher>Ubisoft</publisher>
		<genre>Action</genre>
		<players>2</players>
	</game>
	<game>
		<path>./Tom Clancys Splinter Cell - Pandora Tomorrow (USA).chd</path>
		<name>Tom Clancy's Splinter Cell : Pandora Tomorrow</name>
		<desc>Pandora Tomorrow takes place in Indonesia during the spring of 2006, in which the United States has established a military presence in the newly independent country of East Timor to train that country's military forces in their fight against anti-separatist Indonesian guerrilla militias. Foremost among these Indonesian militias is the Darah Dan Doa (Blood and Prayer), led by Suhadi Sadono.</desc>
		<rating>0.9</rating>
		<releasedate>20040616T000000</releasedate>
		<developer>Ubisoft</developer>
		<publisher>Ubisoft</publisher>
		<genre>Action</genre>
		<players>1-4</players>
	</game>
	<game>
		<path>./Sega Classics Collection (USA).chd</path>
		<name>Sega Classics Collection</name>
		<desc>This single-disc collection, brought Stateside by Conspiracy Entertainment, comprises ten remakes of popular games from Sega's 8- and 16-bit eras which were previously available for PS2 in only Japan and sold individually. In addition to honest emulations of the games, new play modes, game options, and extras are available as well. Included are versions of Alien Syndrome, Bonanza Bros., Columns, Fantasy Zone, Golden Axe, Out Run, Space Harrier, Super Monaco GP, Tanto-R, and Virtua Racing: Flat Out.</desc>
		<rating>0.5</rating>
		<releasedate>20050322T000000</releasedate>
		<developer>SEGA</developer>
		<publisher>SEGA</publisher>
		<genre>Compilation</genre>
		<players>1-4</players>
	</game>
	<game>
		<path>./Sega Genesis Collection (USA).chd</path>
		<name>Sega Genesis Collection</name>
		<desc>For those that had a SEGA Genesis you can now put it away as 28 games are re-released in this compilation to relive your yester-years. For those that never had a SEGA Genesis and didn't play some of the classics on it, well here's your chance to play and be up-to-speed on your game history.

Games included are:
Alex Kidd in the Enchanted Castle
Altered Beast
Bonanza Bros.
Columns
Comix Zone
Decapattack
Ecco the Dolphin 
Ecco: The Tides of Time
Ecco Jr.
Flicky
Gain Ground
Golden Axe
Golden Axe II
Golden Axe III
Kid Chameleon
Phantasy Star II
Phantasy Star III: Generations of Doom
Phantasy Star IV: The End of the Millennium
Ristar
Shadow Dancer: The Secret of Shinobi
Shinobi III: Return of the Ninja Master
Sonic the Hedgehog
Sonic the Hedgehog 2
Super Thunder Blade
Sword of Vermilion
Vectorman
Vectorman 2
Virtua Fighter 2
Also included is bonus content, with unlockable arcade titles, interviews with original SEGA Genesis developers of some of the included games, a museum area with interesting facts about the games, and a hint area with tips.

Games can be saved at any point no matter their own save-game system, you can play Golden Axe and save your game in the middle of fight with Death Adder and load it from that exact point.</desc>
		<rating>0.9</rating>
		<developer>Digital Eclipse</developer>
		<publisher>SEGA</publisher>
		<genre>Compilation</genre>
		<players>2</players>
	</game>
	<game>
		<path>./OutRun 2 SP (Japan) (T-En by SolidSnake11) (i).chd</path>
		<name>OutRun 2 Sp</name>
		<desc>One of Sega's classic racing titles continues its new lease on life with OutRun 2006: Coast 2 Coast, the follow-up to 2004's OutRun2 on Xbox and in the arcades. For its PlayStation 2 debut, OutRun 2006 offers players a choice of 12 licensed Ferraris, from the F430 to the Superamerica, as they put the pedal to the metal for 30 cross-country stages taken from both OutRun2 and OutRun2 SP.
 New twists on the series include mission-based objectives, souped-up or tuned versions of the existing Ferrari lineup, online support for up to six players, and the ability to slipstream behind rivals. Players can also earn Out Run miles throughout each game mode to cash-in for vehicles, courses, and other surprises. As an added bonus, the PlayStation 2 game supports connectivity with the PSP version, granting players the </desc>
		<releasedate>20070208T000000</releasedate>
		<developer>Sumo Digital</developer>
		<publisher>SEGA</publisher>
		<genre>Racing, Driving</genre>
		<players>1</players>
	</game>
	<game>
		<path>./Grand Theft Auto - San Andreas (USA) (v3.00).iso</path>
		<name>Grand Theft Auto : San Andreas</name>
		<desc>Grand Theft Auto: San Andreas takes place within the state San Andreas, which is based on sections of California and Nevada. It comprises three major fictional cities: Los Santos corresponds to real-life Los Angeles; San Fierro corresponds to real-life San Francisco; and Las Venturas and the surrounding desert correspond to real-life Las Vegas and the Nevada and Arizona desert.

The game features set co-op scenarios in a free roam mode as well as a cooperative "rampage" gameplay mode.</desc>
		<rating>1</rating>
		<releasedate>20041026T000000</releasedate>
		<developer>Rockstar North</developer>
		<publisher>Rockstar Games</publisher>
		<genre>Racing, Driving</genre>
		<players>1-2</players>
		<favorite>true</favorite>
		<playcount>1</playcount>
		<lastplayed>20250124T232832</lastplayed>
	</game>
	<game>
		<path>./Simpsons Game The (USA).chd</path>
		<name>The Simpsons Game</name>
		<desc>Bart Simpson goes to a video game store and buys a new ultra-violent Grand Theft Scratchy game, which is promptly confiscated by his mother Marge. Suddenly, a video game manual lands right in front of him. Miraculously, after having read the manual, the members of the Simpsons family discover that each of them possesses a unique superpower. Toying with these, however, attracts the attention of the aliens Kang and Kodos, who decide to invade the Earth. Now the unlikely superheroes must not only protect the town of Springfield from an alien assault, but also find the true reason behind their newly acquired powers, and perhaps their very existence.

</desc>
		<rating>0.7</rating>
		<releasedate>20071102T000000</releasedate>
		<developer>Rebellion</developer>
		<publisher>Electronic Arts</publisher>
		<genre>Platform</genre>
		<players>1-2</players>
	</game>
	<game>
		<path>./Mortal Kombat - Armageddon (USA) (Premium Edition).chd</path>
		<name>Mortal Kombat : Armageddon</name>
		<desc>The fighting genre's poster (whipping?) boy for gruesome violence makes its final appearance on PlayStation 2 before moving in a new direction for Xbox 360 and PlayStation 3. Mortal Kombat: Armageddon is thus a hostile homage to its frenzied fans, a love letter of sorts that tears away the heart-tugging sentiment for the still-beating heart. Armageddon offers the most significant throng of Mortal Kombat fighters thus far, with a roster spanning 62 combatants -- every minor and major character that has appeared in the series to date. The entire cast is also immediately playable from the opening screen.</desc>
		<rating>0.9</rating>
		<releasedate>20061009T000000</releasedate>
		<developer>Midway</developer>
		<publisher>Midway</publisher>
		<genre>Fighting</genre>
		<players>1-8</players>
		<favorite>true</favorite>
	</game>
	<game>
		<path>./Burnout 3 - Takedown (USA).chd</path>
		<name>Burnout 3 : Takedown</name>
		<desc>Burnout 3: Takedown is a racing game which encourages aggressive driving and lets you use your vehicle to smash your way to the finish line by taking out your rivals and causing massive multi-car pileups. The more cars you take out, damage you inflict, the more events and cars you can unlock. Burnout 3 also has a "crash" mode which puts your vehicle at a variety of traffic junctions jam-packed with moving vehicles and pickups to see just how much monetary damage you can inflict.

Burnout 3: Takedown continues the racing series with more cars, more tracks, a more detailed crash engine, and a multitude of new gameplay modes for single players, multiple players on one system, and online play.</desc>
		<rating>0.9</rating>
		<releasedate>20040907T000000</releasedate>
		<developer>Criterion Games</developer>
		<publisher>Electronic Arts</publisher>
		<genre>Racing, Driving</genre>
		<players>1-2</players>
		<favorite>true</favorite>
	</game>
	<game>
		<path>./OutRun 2006 - Coast 2 Coast (USA) (EnFrEs).chd</path>
		<name>OutRun 2006 : Coast 2 Coast</name>
		<desc>OutRun 2006: Coast 2 Coast features 15 unique cars, the most ever seen in any OutRun game. In addition to the ten cars from OutRun 2 SP, new models include the 550 Barchetta, F355 Spider, Superamerica, 328 GTS, and the Ferrari F430. Some models cannot be unlocked on the PlayStation Portable or PlayStation 2 without the use of the cross-system connectivity feature inherent of the two systems.</desc>
		<rating>0.9</rating>
		<releasedate>20060425T000000</releasedate>
		<developer>Sumo Digital</developer>
		<publisher>SEGA</publisher>
		<genre>Racing, Driving</genre>
		<players>2-6</players>
		<favorite>true</favorite>
	</game>
	<game>
		<path>./Grand Theft Auto III (Europe Australia) (EnFrDeEsIt) (v1.60).chd</path>
		<name>Grand Theft Auto III</name>
		<desc>The player character has robbed the Liberty City Bank with his girlfriend, Catalina, and a male accomplice. While running from the scene, Catalina turns to him and utters, "Sorry, babe, I'm an ambitious girl and you ... you're just small-time". She shoots him and leaves him to die in an alley; the accomplice is also seen lying nearby. It soon becomes apparent that the player character has survived but has been arrested and subsequently found guilty and sentenced to jail. While he is being transferred, an attack on the police convoy aimed at kidnapping an unrelated prisoner sets him free.</desc>
		<rating>0.9</rating>
		<releasedate>20011022T000000</releasedate>
		<developer>Rockstar North</developer>
		<publisher>Take 2 Interactive</publisher>
		<genre>Racing, Driving</genre>
		<players>1</players>
		<favorite>true</favorite>
	</game>
	<game>
		<path>./Naruto Shippuden - Ultimate Ninja 5 (Europe) (En,Fr,De,Es,It).iso</path>
		<name>Naruto Shippuden - Ultimate Ninja 5</name>
		<desc>Naruto Shippuden: Ultimate Ninja 5, known in Japan as "Naruto Shippuden: Narutimate Accel 2", features 62 characters and continues the Naruto Shippuden storyline, going up to the end of Sasuke and Sai arc, following the manga (the anime have not done on the arc by then). One of the new gameplay additions is the introduction of assist characters. Assist characters are chosen during character selection, and can be called in during a match to deal extra damage. Certain combinations of characters create unique jutsus in a match; these combinations reflect the associations of those characters in the anime and manga. Many of the character's jutsus from the previous game were updated. There are many updated ultimate jutsus, including the aforementioned assist-specific ones. Summons have been removed from the game. The assist characters cannot be turned off. The game retains the RPG mode from previous game, now allowing the player to control characters other than Naruto (such as Sakura and Kakashi). However, the Hero's History mode that retells the events of the original series have been discarded, though the characters itself remain in the game. It was also the last of the Ultimate Ninja Series for the PlayStation 2. The game was not released in North America.</desc>
		<rating>0.9</rating>
		<releasedate>20071220T000000</releasedate>
		<developer>CyberConnect2</developer>
		<publisher>Bandai Namco</publisher>
		<genre>Fighting</genre>
		<players>2</players>
		<favorite>true</favorite>
	</game>
	<game>
		<path>./Metal Slug Anthology (USA).iso</path>
		<name>Metal Slug Anthology</name>
		<desc>The Metal Slug Anthology features seven previously released games in one package. The bundle includes Metal Slug, Metal Slug 2, Metal Slug X, Metal Slug 3, Metal Slug 4, Metal Slug 5, and Metal Slug 6. 
				 Two-player cooperative action is available, and the game also comes with a variety of unlockable content and a bonus gallery featuring a poster and classic character art.
</desc>
		<rating>0.7</rating>
		<releasedate>20070327T000000</releasedate>
		<developer>Terminal Reality</developer>
		<publisher>SNK</publisher>
		<genre>Shooter / Run and Gun</genre>
		<players>1-2</players>
		<favorite>true</favorite>
	</game>
	<game>
		<path>./Star Wars - Battlefront II (USA) (v2.01).chd</path>
		<name>Star Wars : Battlefront II</name>
		<desc>Battlefront II features a more narrative-based campaign, retelling portions of the Star Wars story from the point of view of a veteran Imperial stormtrooper, reminiscing about his tour of duty in service of both the Galactic Republic and as part of the Galactic Empire. Gameplay additions over Battlefront include the use of Jedi, additional game modes, and objective-based space battles.

Two players can play splitscreen co-op throughout the story campaign or a strategic Galactic Conquest campaign.There is also a "comp stomp" configuration that supports 2 players offline, 2 players splitscreen online, or up to 16 players online.</desc>
		<rating>0.9</rating>
		<releasedate>20051101T000000</releasedate>
		<developer>Pandemic</developer>
		<publisher>LucasArts</publisher>
		<genre>Shooter / FPV</genre>
		<players>2-24</players>
		<favorite>true</favorite>
	</game>
</gameList>
''';
