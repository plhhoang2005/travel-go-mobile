import 'package:flutter/material.dart';

enum MascotType { owl, chameleon, windSprout }

class MapStateProvider extends ChangeNotifier {
  MascotType _activeMascot = MascotType.owl;

  MascotType get activeMascot => _activeMascot;

  void setMascot(MascotType type) {
    _activeMascot = type;
    notifyListeners();
  }
}
