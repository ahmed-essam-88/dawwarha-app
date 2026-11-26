import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../pickup/pickup_screen.dart';
import '../home/home_screen.dart';
import '../scanner/scanner_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final AuthProvider _auth = AuthProvider()..restore();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final pages = <Widget>[
      HomeScreen(onSelectTab: (i) => setState(() => _index = i)),
      const ScannerScreen(),
      _index == 2 ? const MapScreen() : const SizedBox.shrink(), // built only when opened: no location prompt or tile traffic at startup
      const PickupScreen(),
      const ProfileScreen(),
    ];
    return ChangeNotifierProvider<AuthProvider>.value(
      value: _auth,
      child: Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: s.t('tabHome')),
          NavigationDestination(icon: const Icon(Icons.document_scanner_outlined), selectedIcon: const Icon(Icons.document_scanner), label: s.t('tabScan')),
          NavigationDestination(icon: const Icon(Icons.map_outlined), selectedIcon: const Icon(Icons.map), label: s.t('tabMap')),
          NavigationDestination(icon: const Icon(Icons.local_shipping_outlined), selectedIcon: const Icon(Icons.local_shipping), label: s.t('tabPickup')),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: s.t('tabProfile')),
        ],
      ),
    ));
  }
}
