import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/map_state_provider.dart';

class MascotMarkerWidget extends StatelessWidget {
  final MascotType type;
  const MascotMarkerWidget({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color iconColor;
    
    switch (type) {
      case MascotType.owl:
        iconData = Icons.pets;
        iconColor = Colors.blueGrey;
        break;
      case MascotType.chameleon:
        iconData = Icons.bug_report;
        iconColor = Colors.green;
        break;
      case MascotType.windSprout:
        iconData = Icons.air;
        iconColor = Colors.teal;
        break;
    }
    
    return Icon(iconData, size: 48, color: iconColor)
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(begin: -5, end: 5, duration: 1000.ms);
  }
}
