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
  late String path;

  static final Map<String, (DateTime, Uint8List)> _imageCache = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupImage();
  }

  Future<void> _setupImage() async {
    store = GameListStore.ref.of(context);
    path = store.imagePath(widget.game, imageAsset: widget.imageAsset);

    if (kIsWeb && imageBytes == null && !isLoading) {
      try {
        final cached = _imageCache[path];
        if (cached != null) {
          imageBytes = cached.$2;
          _imageCache[path] = (DateTime.now(), imageBytes!);
          return;
        }
        isLoading = true;
        final game = widget.game;
        final a = (widget.imageAsset ?? store.imageAssetType)
            .name
            .replaceFirst(r'$', '');
        final handle = store.paths.downloadedMediaPath.handle;
        if (handle == null) return;

        final paths = '${game.system}/$a'.split('/');
        FileSystemDirectoryHandle dir = handle;
        for (final p in paths) {
          final d = (await dir.getDirectoryHandle(p)).okOrNull;
          if (d == null) return;
          dir = d;
        }
        final fileResult = await dir.getFileHandle('${game.filename}.png');
        final file = fileResult.okOrNull;
        if (file != null) {
          imageBytes = await (await file.getFile()).readAsBytes();
          _imageCache[path] = (DateTime.now(), imageBytes!);
        }
      } finally {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorBuilder = widget.errorBuilder ?? imageAssetErrorBuilder(path);
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
      File(path),
      width: widget.width,
      errorBuilder: errorBuilder,
    );
  }
}
