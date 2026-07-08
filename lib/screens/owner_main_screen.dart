import 'package:flutter/material.dart';
import 'owner_dashboard_screen.dart';
import 'owner_vehicles_screen.dart';
import 'owner_messages_screen.dart';
import 'owner_earnings_screen.dart';
import 'owner_profile_screen.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';

class OwnerMainScreen extends StatefulWidget {
  const OwnerMainScreen({super.key});

  @override
  State<OwnerMainScreen> createState() => _OwnerMainScreenState();
}

class _OwnerMainScreenState extends State<OwnerMainScreen> {
  int _currentIndex = 0;
  bool _showEarningsInsideProfile = false;

  // Simple activity dot, not a numeric count — see BottomNavBar in
  // explore_screen.dart for the full rationale (avoids the N+1 fetch of every
  // conversation's full message history just to count unread items).
  bool _hasActivity = false;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    final me = await AuthService.getCurrentUser();
    if (me == null) return;
    final hasActivity = await MessageService.hasRecentActivity(me.userId);
    if (mounted) setState(() => _hasActivity = hasActivity);
  }

  @override
  Widget build(BuildContext context) {
    Widget profileTabContent;
    if (_showEarningsInsideProfile) {
      profileTabContent = OwnerEarningsScreen(
        onBack: () => setState(() => _showEarningsInsideProfile = false),
      );
    } else {
      profileTabContent = OwnerProfileScreen(
        onNavigateToEarnings: () => setState(() => _showEarningsInsideProfile = true),
      );
    }

    final List<Widget> screens = [
      const OwnerDashboardScreen(),
      const OwnerVehiclesScreen(),
      const OwnerMessagesScreen(),
      profileTabContent,
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home, 'Panel'),
                _buildNavItem(1, Icons.directions_car_outlined, Icons.directions_car, 'Vehículos'),
                _buildNavItem(2, Icons.chat_bubble_outline, Icons.chat_bubble, 'Mensajes'),
                _buildNavItem(3, Icons.person_outline, Icons.person, 'Perfil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final bool isActive = _currentIndex == index;
    final isMessagesTab = index == 2;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
          if (index != 3) _showEarningsInsideProfile = false;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(isActive ? activeIcon : icon, color: isActive ? kCyan : Colors.grey, size: 24),
              if (isMessagesTab && _hasActivity)
                Positioned(
                  right: -2, top: -2,
                  child: Container(
                    key: const Key('owner_bottom_nav_messages_unread_dot'),
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: kCyan, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? kCyan : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}