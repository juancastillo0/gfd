import 'dart:async';

import 'package:gfd/src/base_ui.dart';

class SnackBarsWidget extends StatefulWidget {
  const SnackBarsWidget({
    super.key,
    required this.errors,
    required this.messages,
    required this.child,
  });
  final Stream<String> errors;
  final Stream<String> messages;
  final Widget child;

  @override
  State<SnackBarsWidget> createState() => _SnackBarsWidgetState();
}

class _SnackBarsWidgetState extends State<SnackBarsWidget> {
  StreamSubscription<String>? errorsSubs;
  StreamSubscription<String>? messagesSubs;

  @override
  void initState() {
    super.initState();
    errorsSubs = widget.errors.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ));
    });
    messagesSubs = widget.messages.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ));
    });
  }

  @override
  void dispose() {
    errorsSubs?.cancel();
    messagesSubs?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
