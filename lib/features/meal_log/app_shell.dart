import 'package:flutter/material.dart';

import 'camera_scan_screen.dart';
import 'home_screen.dart';
import 'plan_screen.dart';

/// Bottom-nav shell with a raised center camera button, matching the
/// reference design's tab bar.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tabIndex = 0;

  static const _tabs = [HomeScreen(), PlanScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _tabIndex, children: _tabs),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        shape: const CircleBorder(),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CameraScanScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shadowColor: Colors.black,
        elevation: 8,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(
                Icons.home,
                color: _tabIndex == 0
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.outline,
              ),
              onPressed: () => setState(() => _tabIndex = 0),
            ),
            IconButton(
              icon: Icon(
                Icons.calendar_month,
                color: _tabIndex == 1
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.outline,
              ),
              onPressed: () => setState(() => _tabIndex = 1),
            ),
          ],
        ),
      ),
    );
  }
}
