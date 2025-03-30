export 'package:context_plus/context_plus.dart';
export 'package:flutter/material.dart' hide Text;

import 'package:context_plus/context_plus.dart';
import 'package:gfd/src/collections/collection_list_view.dart';
import 'package:gfd/src/gamelist/game_list_view.dart';
import 'package:gfd/src/gamelist/game_state.dart';
import 'package:gfd/src/settings/settings_view.dart';
import 'package:gfd/src/utils/snackbars_widget.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material;

typedef Text = SelectableText;
typedef TextNoSelect = material.Text;

class MainPage extends StatefulWidget {
  const MainPage({required this.tab, super.key});
  final MainTab tab;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.tab.index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = GameListStore.ref.of(context);

    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          width: 400,
          child: TabBar(
            dividerColor: Colors.transparent,
            controller: tabController,
            tabs: ['Games', 'Collections']
                .map(
                  (e) => Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: TextNoSelect(e),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.restorablePushNamed(context, SettingsView.routeName);
            },
          ),
        ],
      ),
      body: Material(
        child: SnackBarsWidget(
          errors: store.errorsStream,
          messages: store.messagesStream,
          child: TabBarView(
            controller: tabController,
            children: const [
              GameListView(),
              CollectionsListView(),
            ],
          ),
        ),
      ),
    );
  }
}

enum MainTab {
  games,
  collections,
}
