import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design_system/theme/peerlink_theme.dart';
import 'design_system/components/active_transfer_pill.dart';
import 'design_system/components/contextual_share_sheet.dart';
import 'design_system/components/floating_audio_mini_player.dart';
import 'design_system/components/persistent_staged_tray.dart';
import 'platform/android_node_bridge.dart';
import 'platform/desktop_shell_bridge.dart';
import 'platform/windows_node_manager.dart';
import 'features/files/file_manager_home_screen.dart';
import 'features/devices/devices_screen.dart';
import 'features/activity/activity_screen.dart';
import 'features/spaces/spaces_screen.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screen.dart';
import 'core/file_staging_service.dart';
import 'core/quick_text_service.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  if (args.isNotEmpty) {
    final fileArgs = args.where((a) => !a.startsWith('--')).toList();
    if (fileArgs.isNotEmpty) {
      DesktopShellBridge.instance.recordLaunchArgs(fileArgs);
    }
  }
  runApp(const PeerLinkApp());
}

class PeerLinkApp extends StatefulWidget {
  final bool? overrideOnboardingCompleted;
  const PeerLinkApp({super.key, this.overrideOnboardingCompleted});

  @override
  State<PeerLinkApp> createState() => _PeerLinkAppState();
}

class _PeerLinkAppState extends State<PeerLinkApp> {
  @override
  void initState() {
    super.initState();
    try {
      if (Platform.isWindows && !WindowsNodeManager.isTestEnvironment) {
        WindowsNodeManager.instance.autoStartAndAuthenticate();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PeerLink',
      debugShowCheckedModeBanner: false,
      theme: PeerLinkTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  final int initialIndex;
  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;
  DateTime? _lastBackPressTime;
  StreamSubscription<List<String>>? _sharedIntentSub;
  StreamSubscription<List<String>>? _desktopDropSub;
  StreamSubscription<void>? _trayQuickSendSub;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _sharedIntentSub = AndroidNodeBridge.instance.sharedFilesStream.listen((uris) {
      if (uris.isNotEmpty && mounted) {
        ContextualShareSheet.show(context, initialPaths: uris);
      }
    });
    _desktopDropSub = DesktopShellBridge.instance.droppedFilesStream.listen((paths) {
      if (paths.isNotEmpty && mounted) {
        ContextualShareSheet.show(context, initialPaths: paths);
      }
    });
    _trayQuickSendSub = DesktopShellBridge.instance.trayQuickSendStream.listen((_) {
      if (mounted) {
        ContextualShareSheet.show(context);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkColdStartSharedIntent();
    });
  }

  Future<void> _checkColdStartSharedIntent() async {
    final desktopArgs = DesktopShellBridge.instance.consumeLaunchArgs();
    if (desktopArgs.isNotEmpty && mounted) {
      ContextualShareSheet.show(context, initialPaths: desktopArgs);
      return;
    }

    final pending = await AndroidNodeBridge.instance.consumePendingShareIntent();
    if (!mounted || pending == null) return;
    final uris = (pending['uris'] as List<dynamic>?)?.cast<String>() ?? const [];
    final text = pending['text'] as String?;
    if (text != null && text.isNotEmpty) {
      QuickTextService.instance.addSnippet(text);
    }
    if (uris.isNotEmpty) {
      FileStagingService.instance.addPaths(uris);
      if (mounted) {
        ContextualShareSheet.show(context, initialPaths: uris);
      }
    }
  }

  @override
  void dispose() {
    _sharedIntentSub?.cancel();
    _desktopDropSub?.cancel();
    _trayQuickSendSub?.cancel();
    super.dispose();
  }

  void _navigateTo(int index) {
    if (mounted && index >= 0 && index < 6) {
      setState(() => _currentIndex = index);
    }
  }

  Widget _buildActiveScreen(int index) {
    switch (index) {
      case 0:
        return FileManagerHomeScreen(
          key: const ValueKey('tab_files'),
          onNavigate: _navigateTo,
          showBottomNav: false,
        );
      case 1:
        return DevicesScreen(key: const ValueKey('tab_devices'), onNavigate: _navigateTo);
      case 2:
        return const ActivityScreen(key: ValueKey('tab_activity'));
      case 3:
        return SpacesScreen(key: const ValueKey('tab_spaces'), onNavigate: _navigateTo);
      case 4:
        return SearchScreen(key: const ValueKey('tab_search'), onNavigate: _navigateTo);
      case 5:
        return SettingsScreen(key: const ValueKey('tab_settings'), onNavigate: _navigateTo);
      default:
        return FileManagerHomeScreen(
          key: const ValueKey('tab_files'),
          onNavigate: _navigateTo,
          showBottomNav: false,
        );
    }
  }

  Widget _buildAnimatedBody(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        if (disableAnimations) return child;
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: _buildActiveScreen(_currentIndex),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit PeerLink'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 600;

          if (isDesktop) {
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) {
                      HapticFeedback.selectionClick();
                      setState(() => _currentIndex = index);
                    },
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.folder_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.folder_outlined),
                        selectedIcon: Icon(Icons.folder_rounded),
                        label: Text('Files'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.devices_outlined),
                        selectedIcon: Icon(Icons.devices_rounded),
                        label: Text('Devices'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.history_outlined),
                        selectedIcon: Icon(Icons.history_rounded),
                        label: Text('Activity'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.group_work_outlined),
                        selectedIcon: Icon(Icons.group_work_rounded),
                        label: Text('Spaces'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.search_outlined),
                        selectedIcon: Icon(Icons.search_rounded),
                        label: Text('Search'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings_rounded),
                        label: Text('Settings'),
                      ),
                    ],
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: _buildAnimatedBody(context)),
                        const FloatingAudioMiniPlayer(),
                        ActiveTransferPill(
                          onOpenActivity: () => _navigateTo(2),
                        ),
                        PersistentStagedTray(
                          onReviewPressed: () => ContextualShareSheet.show(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // Mobile Viewport (< 600dp width)
          // Focused 3-tab Xiaomi File Manager shell: Files | Devices | Activity
          // (Sharing appears contextually on demand via ContextualShareSheet — no separate Share page)
          final mobileIndex = _currentIndex < 3 ? _currentIndex : 0;

          return Scaffold(
            body: Column(
              children: [
                Expanded(child: _buildAnimatedBody(context)),
                const FloatingAudioMiniPlayer(),
                ActiveTransferPill(
                  onOpenActivity: () => _navigateTo(2),
                ),
                PersistentStagedTray(
                  onReviewPressed: () => ContextualShareSheet.show(context),
                ),
              ],
            ),
            bottomNavigationBar: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB), width: 1.0),
                ),
              ),
              child: NavigationBar(
                selectedIndex: mobileIndex,
                onDestinationSelected: (index) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _currentIndex = index;
                  });
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon: Icon(Icons.folder_rounded),
                    label: 'Files',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.devices_outlined),
                    selectedIcon: Icon(Icons.devices_rounded),
                    label: 'Devices',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history_rounded),
                    label: 'Activity',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
