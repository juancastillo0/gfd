import 'dart:collection';
import 'dart:io';

import 'package:gfd/src/gamelist/game_data.dart';
import 'package:gfd/src/gamelist/game_details_view.dart';
import 'package:gfd/src/gamelist/game_model.dart';
import 'package:gfd/src/gamelist/game_state.dart';
import 'package:gfd/src/base_ui.dart';
import 'package:gfd/src/system_collection/system_model.dart';
import 'package:file_system_access/file_system_access.dart';
import 'package:flutter/foundation.dart';

class GameImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final store = (GameListStore.ref..watch(context)).of(context);
    return FSAImage(
      path: store.imagePath(game, imageAsset: imageAsset),
      errorBuilder: errorBuilder,
      width: width,
      pathHandle: game.system == 'pc'
          ? store.paths.playniteLibraryPath
          : store.paths.downloadedMediaPath,
    );
  }
}

class FSAImage extends StatefulWidget {
  const FSAImage({
    super.key,
    required this.pathHandle,
    required this.path,
    this.errorBuilder,
    this.width,
  });

  final GameListPath<FileSystemDirectoryHandle> pathHandle;
  final String path;
  final double? width;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  State<FSAImage> createState() => _FSAImageState();
}

class _FSAImageState extends State<FSAImage> {
  Uint8List? imageBytes;
  bool isLoading = false;
  late GameListStore store;
  String? path;
  GetHandleErrorType? error;

  static final Map<String, (DateTime, Uint8List)> _imageCache = {};
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupImage();
  }

  @override
  void didUpdateWidget(covariant FSAImage oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    path = widget.path;

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
        final handle = widget.pathHandle.handle;
        if (handle == null) return;
        String prefix = widget.pathHandle.controller.text;
        if (!prefix.endsWith('/')) prefix = '$prefix/';

        final relativePath = newPath.contains(prefix)
            ? newPath.substring(newPath.lastIndexOf(prefix) + prefix.length)
            : newPath;
        final fileResult = await handle.getNestedFileHandle(relativePath);
        final file = fileResult.okOrNull;
        if (file != null) {
          imageBytes = await (await file.getFile()).readAsBytes();
          _imageCache[newPath] = (DateTime.now(), imageBytes!);
          validateCache();
          error = null;
        } else {
          error = fileResult.errOrNull!.type;
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
    return SizedBox(
      width: widget.width,
      child: Builder(
        builder: (context) {
          if (kIsWeb) {
            if (isLoading) {
              return Padding(
                padding: const EdgeInsets.all(18.0),
                child: Center(child: const CircularProgressIndicator()),
              );
            } else if (imageBytes == null) {
              return Text(
                widget.pathHandle.handle == null
                    ? 'No Media Asset Directory Handle'
                    : 'No image ${error?.toString() ?? ''}. "$path"',
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
        },
      ),
    );
  }
}
