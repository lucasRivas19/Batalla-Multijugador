import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/socket_service.dart';
import 'screen/battle_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SocketService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Batalla Multijugador',
      theme: ThemeData.dark(),
      home: const BattleScreen(),
    );
  }
}
