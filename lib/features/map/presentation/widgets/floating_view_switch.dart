import 'package:flutter/material.dart';

enum JourneyViewMode {
  map,
  story,
}

class FloatingViewSwitch extends StatelessWidget {
  final JourneyViewMode currentMode;
  final ValueChanged<JourneyViewMode> onModeChanged;

  const FloatingViewSwitch({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6EDF5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2212447D),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildItem(
            label: 'Bản đồ',
            icon: Icons.layers_rounded,
            isActive: currentMode == JourneyViewMode.map,
            onTap: () => onModeChanged(JourneyViewMode.map),
          ),
          const SizedBox(width: 4),
          _buildItem(
            label: 'Hành trình',
            icon: Icons.view_timeline_rounded,
            isActive: currentMode == JourneyViewMode.story,
            onTap: () => onModeChanged(JourneyViewMode.story),
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF102037) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? Colors.white : const Color(0xFF5E718B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : const Color(0xFF5E718B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
