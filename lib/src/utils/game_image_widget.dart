import 'dart:collection';
import 'dart:io';

import 'package:eset/src/gamelist/game_details_view.dart';
import 'package:eset/src/gamelist/game_model.dart';
import 'package:eset/src/gamelist/game_state.dart';
import 'package:eset/src/base_ui.dart';
import 'package:eset/src/system_collection/system_model.dart';
import 'package:file_system_access/file_system_access.dart';
import 'package:flutter/foundation.dart';

class GameImage extends StatefulWidget {
  const GameImage({
    super.key,
    required this.game,
    this.errorBuilder,
    this.imageAsset,
    this.width,
  });

  final Game game;
  final SystemImageAsset? imageAsset;
  final double? width;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  State<GameImage> createState() => _GameImageState();
}

class _GameImageState extends State<GameImage> {
  Uint8List? imageBytes;
  bool isLoading = false;
  late GameListStore store;
  String? path;

  static final Map<String, (DateTime, Uint8List)> _imageCache = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupImage();
  }

  void validateCache() {
    if (_imageCache.length > 100) {
      final now = DateTime.now();
      _imageCache
          .removeWhere((key, value) => now.difference(value.$1).inMinutes > 5);
      if (_imageCache.length > 100) {
        final keys = SplayTreeMap<DateTime, String>.from(
          _imageCache.map((k, v) => MapEntry(v.$1, k)),
        ).values.take(50).toSet();
        _imageCache.removeWhere((k, _) => !keys.contains(k));
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    store.removeListener(_setupImage);
  }

  Future<void> _setupImage() async {
    store = GameListStore.ref.of(context);
    if (path == null) store.addListener(_setupImage);

    final previousPath = path;
    path = store.imagePath(widget.game, imageAsset: widget.imageAsset);

    if (kIsWeb && (imageBytes == null || path != previousPath) && !isLoading) {
      final newPath = path!;
      try {
        final cached = _imageCache[newPath];
        if (cached != null) {
          imageBytes = cached.$2;
          _imageCache[newPath] = (DateTime.now(), imageBytes!);
          return;
        }
        isLoading = true;
        final game = widget.game;
        final isPlaynite = game.system == 'pc';
        final handle = isPlaynite
            ? store.paths.playniteLibraryPath.handle
            : store.paths.downloadedMediaPath.handle;
        if (handle == null) return;
        String prefix = isPlaynite
            ? store.playniteLibraryPath.text
            : store.downloadedMediaPath.text;
        if (!prefix.endsWith('/')) prefix = '$prefix/';

        final fileResult = await handle.getNestedFileHandle(
          newPath.substring(newPath.lastIndexOf(prefix) + prefix.length),
        );
        final file = fileResult.okOrNull;
        if (file != null) {
          imageBytes = await (await file.getFile()).readAsBytes();
          _imageCache[newPath] = (DateTime.now(), imageBytes!);
          validateCache();
        }
      } finally {
        if (mounted) {
          setState(() {
            isLoading = false;
            if (newPath != path) {
              _setupImage();
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorBuilder = widget.errorBuilder ?? imageAssetErrorBuilder(path!);
    if (kIsWeb) {
      if (isLoading) {
        return Center(child: const CircularProgressIndicator());
      } else if (imageBytes == null) {
        return Text(
          store.paths.downloadedMediaPath.handle == null
              ? 'No Downloaded Media Handle'
              : 'No image',
        );
      }
      return Image.memory(
        imageBytes!,
        width: widget.width,
        errorBuilder: errorBuilder,
      );
    }
    return Image.file(
      File(path!),
      width: widget.width,
      errorBuilder: errorBuilder,
    );
  }
}
