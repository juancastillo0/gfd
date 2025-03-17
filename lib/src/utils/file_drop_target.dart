import 'dart:async';

// import 'package:desktop_drop/desktop_drop.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:eset/src/base_ui.dart';
import 'package:file_system_access/file_system_access.dart';
import 'package:flutter/foundation.dart';

class FileDropTarget extends StatefulWidget {
  const FileDropTarget({
    super.key,
    required this.onDrop,
  });

  final void Function(List<FileSystemFileWebSafe>) onDrop;

  @override
  _FileDropTargetState createState() => _FileDropTargetState();
}

class _FileDropTargetState extends State<FileDropTarget> {
  // final List<FileSystemFileWebSafe> _list = [];

  bool _dragging = false;

  final globalKey = GlobalKey();
  StreamSubscription<DropFileEvent>? subs;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      subs = FileSystem.instance.webDropFileEvents().listen((event) {
        final position = _getWidgetPosition(globalKey);

        if (!position.contains(Offset(event.pageX, event.pageY))) {
          if (_dragging) setState(() => _dragging = false);
          return;
        } else if (event.items.isEmpty) {
          if (!_dragging) setState(() => _dragging = true);
          return;
        }

        List<FileSystemFileWebSafe> expandDrop(FileSystemItemWebSafe item) {
          return item
              .map(
                directory: (directory) =>
                    directory.children.expand(expandDrop).toList(),
                file: (file) => [file],
              )
              .toList();
        }

        // TODO: show directory?
        onSelect(
          event.items.expand(expandDrop).toList(),
        );
      });
    }
  }

  void onSelect(List<FileSystemFileWebSafe> files) {
    setState(() {
      _dragging = false;
      widget.onDrop(files);
    });
  }

  @override
  void dispose() {
    subs?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        _dragging ? Colors.blue.withAlpha((255 * 0.4).toInt()) : Colors.black12;
    final container = Container(
      key: globalKey,
      height: 50,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Center(
        child: TextNoSelect(
          "Drop file or click to select",
          textAlign: TextAlign.center,
        ),
      ),
    );
    if (kIsWeb) {
      return container;
    }
    return SizedBox(
      width: 100,
      child: DropTarget(
        onDragDone: (detail) {
          final files = detail.files
              .map(
                (f) => FileSystemFileWebSafe(
                  file: f,
                  handle: FileSystem.instance.getIoNativeHandleFromPath(f.path)
                      as FileSystemFileHandle,
                ),
              )
              .toList();
          onSelect(files);
        },
        onDragEntered: (detail) {
          setState(() {
            _dragging = true;
          });
        },
        onDragExited: (detail) {
          setState(() {
            _dragging = false;
          });
        },
        child: container,
      ),
    );
  }
}

Rect _getWidgetPosition(GlobalKey key) {
  final RenderBox renderBox =
      key.currentContext?.findRenderObject()! as RenderBox;

  final leftTop = renderBox.localToGlobal(Offset.zero);
  final rightBottom =
      renderBox.localToGlobal(renderBox.size.bottomRight(Offset.zero));
  return Rect.fromPoints(leftTop, rightBottom); // top-left point of the widget
}
