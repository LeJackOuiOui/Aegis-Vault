import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/safehouse_model.dart';
import '../services/supabase_service.dart';
import '../services/proximity_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final ProximityService _proximityService = ProximityService();

  late Future<List<Safehouse>> _safehousesFuture;
  bool _isOfflineMode = false;
  bool _isNearNeonVault = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _initConnectivityMonitor();
    _proximityService.startProximityMonitoring((isNear) {
      if (mounted) setState(() => _isNearNeonVault = isNear);
    });
    _loadSafehouses();
  }

  void _initConnectivityMonitor() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (!hasConnection && !_isOfflineMode) {
        // Sin conexión: cargar desde caché encriptado
        setState(() {
          _isOfflineMode = true;
          _safehousesFuture = _supabaseService.fetchFromCache();
        });
      } else if (hasConnection && _isOfflineMode) {
        // Conexión restaurada: sincronizar con Supabase
        setState(() {
          _isOfflineMode = false;
          _safehousesFuture = _supabaseService.fetchSafehouses();
        });
      }
    });
  }

  void _loadSafehouses() {
    _safehousesFuture = _supabaseService.fetchSafehouses().catchError((_) {
      // Si falla la red en la carga inicial, usar caché
      setState(() => _isOfflineMode = true);
      return _supabaseService.fetchFromCache();
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _proximityService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aegis Vault - Refugios'),
        centerTitle: true,
        // Indicador visual si se está cerca del Neon-Vault
        actions: [
          if (_isNearNeonVault)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Tooltip(
                message: '¡Proximidad al Neon-Vault detectada!',
                child: Icon(Icons.radar, color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // === BANNER DE MODO DESCONECTADO ===
          if (_isOfflineMode)
            Container(
              width: double.infinity,
              color: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Modo Desconectado - Datos Locales Protegidos',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // === LISTA DE REFUGIOS ===
          Expanded(
            child: FutureBuilder<List<Safehouse>>(
              future: _safehousesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Sincronizando con la red Aegis...',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            size: 64,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'CONEXIÓN COMPROMETIDA',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => setState(() => _loadSafehouses()),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar Enlace'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No se encontraron refugios activos.'),
                  );
                }

                final safehouses = snapshot.data!;

                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: safehouses.length,
                    itemBuilder: (context, index) {
                      final safehouse = safehouses[index];
                      final bool isCompromised = safehouse.isCompromised;

                      final cardColor = isCompromised
                          ? theme.colorScheme.errorContainer
                          : theme.colorScheme.surfaceContainerHigh;

                      final textColor = isCompromised
                          ? theme.colorScheme.onErrorContainer
                          : theme.colorScheme.onSurface;

                      final iconColor = isCompromised
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary;

                      return GestureDetector(
                        onDoubleTap: _isOfflineMode
                            ? null // Sin conexión no se puede modificar
                            : () async {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Actualizando estado en la red central Aegis...',
                                    ),
                                    duration: Duration(milliseconds: 500),
                                  ),
                                );
                                try {
                                  await _supabaseService.toggleSafehouseStatus(
                                    safehouse.id,
                                    isCompromised,
                                  );
                                  setState(() => _loadSafehouses());
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: theme.colorScheme.error,
                                    ),
                                  );
                                }
                              },
                        // === ACCESIBILIDAD ESENCIAL ===
                        child: Semantics(
                          excludeSemantics: true,
                          label:
                              "Refugio ${safehouse.codename}, ubicado en el sector ${safehouse.sector}, capacidad para ${safehouse.capacity} agentes.",
                          child: Card(
                            elevation: 3,
                            color: cardColor,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isCompromised
                                                ? Icons.warning_amber_rounded
                                                : Icons.gpp_good,
                                            color: iconColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              safehouse.codename,
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: textColor,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(),
                                      Text(
                                        'Sector:',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: textColor.withValues(
                                                alpha: 0.7,
                                              ),
                                            ),
                                      ),
                                      Text(
                                        safehouse.sector,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: textColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Capacidad:',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: textColor.withValues(
                                                alpha: 0.7,
                                              ),
                                            ),
                                      ),
                                      Chip(
                                        label: Text(
                                          '${safehouse.capacity} Agp',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: textColor,
                                          ),
                                        ),
                                        backgroundColor: theme
                                            .colorScheme
                                            .surface
                                            .withValues(alpha: 0.4),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
