import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/chat_provider.dart';
import '../../services/order_service.dart';
import '../../services/user_session_service.dart';
import 'chat_screen.dart';
import 'map_screen.dart';
import 'order_list_screen.dart';
import 'profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({
    super.key,
    required this.isDarkMode,
    required this.onThemeModeChanged,
    required this.orderService,
    required this.userSessionService,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeModeChanged;
  final OrderService orderService;
  final UserSessionService userSessionService;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  void _openChatRoom(String roomId) {
    context.read<ChatProvider>().selectRoom(roomId);
    setState(() {
      _currentIndex = 2;
    });
  }

  @override
  void initState() {
    super.initState();
    _screens = <Widget>[
      MapScreen(
        orderService: widget.orderService,
        userSessionService: widget.userSessionService,
        onOpenChat: (roomId) async => _openChatRoom(roomId),
      ),
      OrderListScreen(
        orderService: widget.orderService,
        userSessionService: widget.userSessionService,
        onOpenChat: (roomId) async => _openChatRoom(roomId),
      ),
      const ChatScreen(),
      ProfileScreen(
        isDarkMode: widget.isDarkMode,
        onThemeModeChanged: widget.onThemeModeChanged,
      ),
    ];
  }

  @override
  void didUpdateWidget(covariant MainNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.onThemeModeChanged != widget.onThemeModeChanged) {
      _screens[3] = ProfileScreen(
        isDarkMode: widget.isDarkMode,
        onThemeModeChanged: widget.onThemeModeChanged,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Bản đồ',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Đơn hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Trò chuyện',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}
