import 'package:flutter/material.dart';

class ThaliaRouterDelegate extends ChangeNotifier with NavigatorObserver {
  ThaliaRouterDelegate.undefined();

  void replace (MaterialPage page) {

  }


  static ThaliaRouterDelegate of (BuildContext context) => ThaliaRouterDelegate.undefined();
}




class TypedMaterialPage extends MaterialPage {
  final String name;

  TypedMaterialPage({required Widget child, required this.name}) : super(child: child);

}