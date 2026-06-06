import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Supabase con la Red Central de Aegis Vault

  runApp(const AegisVaultApp());
}

class AegisVaultApp extends StatelessWidget {
  const AegisVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aegis Vault',
      debugShowCheckedModeBanner: false,
      // Activación explícita de Material 3 y esquema de colores dinámico
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor:
              Colors.teal, // Color temático de agentes secretos/tecnología
          brightness:
              Brightness.dark, // Modo oscuro ideal para operaciones de campo
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
