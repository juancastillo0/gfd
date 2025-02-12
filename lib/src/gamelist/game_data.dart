import 'package:eset/src/system_collection/game_filter_model.dart';
import 'package:eset/src/system_collection/system_model.dart';
import 'package:file_system_access/file_system_access.dart' as fsa;
import 'package:eset/src/base_ui.dart';
import 'package:flutter/foundation.dart';

class GameListData {
  GameListData({
    required this.selectedGamePath,
    required this.paths,
    required this.storedFilter,
    required this.storedFilters,
    required this.showFilter,
    required this.isGridView,
    required this.imageAssetType,
    required this.isFiltering,
    required this.imageWidth,
  });

  final String? selectedGamePath;
  final GameListPaths? paths;
  final String? storedFilter;
  final Map<String, GameFilter>? storedFilters;
  final bool? showFilter;
  final bool? isGridView;
  final SystemImageAsset? imageAssetType;
  final bool? isFiltering;
  final double? imageWidth;

  factory GameListData.fromJson(Map<String, Object?> json) {
    return GameListData(
      selectedGamePath: json['selectedGamePath'] as String?,
      paths: json['paths'] == null
          ? null
          : GameListPaths.fromJson(json['paths'] as Map<String, Object?>),
      storedFilter: json['storedFilter'] as String?,
      storedFilters: (json['storedFilters'] as Map<String, Object?>?)?.map(
        (k, e) => MapEntry(k, GameFilter.fromJson(e as Map)),
      ),
      showFilter: json['showFilter'] as bool?,
      isGridView: json['isGridView'] as bool?,
      imageAssetType: json['imageAssetType'] == null
          ? null
          : SystemImageAsset.values.firstWhere(
              (e) => e.name == json['imageAssetType'] as String,
              orElse: () => SystemImageAsset.covers,
            ),
      isFiltering: json['isFiltering'] as bool?,
      imageWidth: (json['imageWidth'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'selectedGamePath': selectedGamePath,
      'paths': paths,
      'storedFilter': storedFilter,
      'storedFilters': storedFilters,
      'showFilter': showFilter,
      'isGridView': isGridView,
      'imageAssetType': imageAssetType?.name,
      'isFiltering': isFiltering,
      'imageWidth': imageWidth,
    };
  }
}

class GameListPaths {
  GameListPaths();

  final downloadedMediaPath = GameListPath<fsa.FileSystemDirectoryHandle>(
    text: defaultTargetPlatform == TargetPlatform.windows
        ? 'D:/Emulation/storage/downloaded_media'
        : '/Volumes/KINGSTON/games/Emulation/storage/downloaded_media',
  );
  final esDeAppDataConfigPath = GameListPath<fsa.FileSystemDirectoryHandle>(
    text: defaultTargetPlatform == TargetPlatform.windows
        ? 'F:/games/Emulation/ES-DE'
        : '/Volumes/KINGSTON/games/Emulation/ES-DE',
  );
  final playniteLibraryPath = GameListPath<fsa.FileSystemDirectoryHandle>(
    text: '/Volumes/KINGSTON/games/Playnite/library/',
  );

  Map<String, Object?> toJson() {
    return {
      'downloadedMediaPath': downloadedMediaPath,
      'esDeAppDataConfigPath': esDeAppDataConfigPath,
      'playniteLibraryPath': playniteLibraryPath,
    };
  }

  factory GameListPaths.fromJson(Map<String, Object?> json) {
    final p = GameListPaths();
    final v = json['downloadedMediaPath'] as Map<String, Object?>?;
    if (v != null) p.downloadedMediaPath.populate(v);
    final v2 = json['esDeAppDataConfigPath'] as Map<String, Object?>?;
    if (v2 != null) p.esDeAppDataConfigPath.populate(v2);
    final v3 = json['playniteLibraryPath'] as Map<String, Object?>?;
    if (v3 != null) p.playniteLibraryPath.populate(v3);
    return p;
  }
}

class GameListPath<H extends fsa.FileSystemHandle> {
  final TextEditingController controller;
  int? persistedId;
  H? handle;

  GameListPath({
    required String text,
    this.persistedId,
  }) : controller = TextEditingController(text: text);

  Future<void> setHandle(H h) async {
    if (kIsWeb) {
      final p = await fsa.FileSystem.instance.getPersistance();
      final entity = await p.put(h);
      persistedId = entity.id;
    }
    handle = h;
    controller.text = h.name;
  }

  Map<String, Object?> toJson() {
    return {
      'path': controller.text,
      'persistedId': persistedId,
    };
  }

  void populate(Map<String, Object?> v) {
    controller.text = v['path'] as String? ?? controller.text;
    persistedId = v['persistedId'] as int? ?? persistedId;
  }
}
