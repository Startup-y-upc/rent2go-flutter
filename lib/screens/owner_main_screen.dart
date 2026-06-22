import 'package:flutter/material.dart';
import 'owner_dashboard_screen.dart';
import 'owner_vehicles_screen.dart';
import 'owner_messages_screen.dart';
import 'owner_earnings_screen.dart';
import 'owner_profile_screen.dart';
import '../widgets/common_widgets.dart';

class OwnerMainScreen extends StatefulWidget {
  const OwnerMainScreen({super.key});

  @override
  State<OwnerMainScreen> createState() => _OwnerMainScreenState();
}

class _OwnerMainScreenState extends State<OwnerMainScreen> {
  int _currentIndex = 0;
  bool _showEarningsInsideProfile = false;

  @override
  Widget build(BuildContext context) {
    // Determine which screen to show for the "Profile" tab
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

    final List<Widget> _screens = [
      const OwnerDashboardScreen(),
      const OwnerVehiclesScreen(),
      const OwnerMessagesScreen(),
      profileTabContent,
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
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
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
          // Reset profile state when switching to other tabs or clicking profile tab again
          if (index != 3) {
            _showEarningsInsideProfile = false;
          }
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive ? kCyan : Colors.grey,
            size: 24,
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
