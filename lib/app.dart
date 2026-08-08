import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/presence_tab.dart';
import 'screens/identity_tab.dart';
import 'screens/messages_tab.dart';
import 'screens/galaxy_tab.dart';
import 'core/theme.dart';

class HermesCompanion extends StatelessWidget {
  const HermesCompanion({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: HermesTheme.bg, primaryColor: HermesTheme.gold),
      home: const CompanionShell(),
    );
  }
}

class CompanionShell extends StatefulWidget {
  const CompanionShell({super.key});
  @override
  State<CompanionShell> createState() => _CompanionShellState();
}

class _CompanionShellState extends State<CompanionShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    PresenceTab.onNavigate = (tab) => setState(() => _index = tab);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      const PresenceTab(),
      const IdentityTab(),
      const MessagesTab(),
      const GalaxyTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: HermesTheme.surface, border: Border(top: BorderSide(color: Colors.white10))),
        child: SafeArea(
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _navItem(0, '灯泡', Icons.circle, isGold: _index == 0),
            _navItem(1, '身份', Icons.fingerprint),
            _navItem(2, '消息', Icons.inbox),
            _navItem(3, '分身', Icons.hub),
          ]),
        ),
      ),
    );
  }

  Widget _navItem(int i, String label, IconData icon, {bool isGold = false}) {
    final active = _index == i;
    final color = active ? (isGold ? HermesTheme.gold : HermesTheme.silver) : HermesTheme.textMuted;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.mediumImpact();
          setState(() => _index = i);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          SizedBox(height: 3),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ]),
        ),
      ),
    );
  }
}
