import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/models/estacion.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'add_estacion.dart';
import 'login_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService apiService = ApiService();
  Timer? _refreshTimer;

  // Manejo de estado limpio en memoria
  List<Estacion> _estaciones = [];
  List<dynamic> _lecturas = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarTodo();

    //Llama a la API en segundo plano sin parpadear la pantalla
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _cargarDatosEnSegundoPlano();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Carga inicial
  Future<void> _cargarTodo() async {
    try {
      final estacionesData = await apiService.fetchEstaciones();
      final lecturasData = await apiService.fetchLecturas();
      if (mounted) {
        setState(() {
          _estaciones = estacionesData;
          _lecturas = lecturasData;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Trae datos de FastAPI de forma silenciosa cada 3 segundos
  Future<void> _cargarDatosEnSegundoPlano() async {
    try {
      final estacionesData = await apiService.fetchEstaciones();
      final lecturasData = await apiService.fetchLecturas();
      if (mounted) {
        setState(() {
          _estaciones = estacionesData;
          _lecturas = lecturasData;
        });
      }
    } catch (e) {
      debugPrint("Error en autorefresco: $e");
    }
  }

  void _logout() async {
    _refreshTimer?.cancel();
    await AuthService().logout();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _mostrarDialogoEdicion(Estacion estacion) {
    final nombreCtrl = TextEditingController(text: estacion.nombre);
    final ubicacionCtrl = TextEditingController(text: estacion.ubicacion);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Estación"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: "Nombre")),
            TextField(
                controller: ubicacionCtrl,
                decoration: const InputDecoration(labelText: "Ubicación")),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              bool ok = await apiService.editarEstacion(
                  estacion.id, nombreCtrl.text, ubicacionCtrl.text);

              if (ok) {
                if (!context.mounted) return;
                Navigator.pop(context);
                _cargarTodo();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Estación actualizada correctamente")),
                );
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estaciones SMAT'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: _logout,
          ),
        ],
      ),
      // Control de estados visuales principales sin FutureBuilder
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : _estaciones.isEmpty
                  ? const Center(child: Text('No hay estaciones registradas.'))
                  : RefreshIndicator(
                      onRefresh: _cargarTodo,
                      child: ListView.builder(
                        itemCount: _estaciones.length,
                        itemBuilder: (context, index) {
                          final estacion = _estaciones[index];

                          // LÓGICA DE FILTRADO DE LECTURAS (Sincronizada en memoria)
                          String valorTexto = "0.0 cm";
                          bool esCritico = false;

                          final lecturasDeEstaEstacion = _lecturas.where((l) {
                            final idEstacionLectura =
                                l['estacion_id'] ?? l['estacionId'];
                            return idEstacionLectura.toString() ==
                                estacion.id.toString();
                          }).toList();

                          if (lecturasDeEstaEstacion.isNotEmpty) {
                            final ultimaLectura = lecturasDeEstaEstacion.last;
                            final double valor = double.tryParse(
                                    ultimaLectura['valor'].toString()) ??
                                0.0;

                            valorTexto = "${valor.toStringAsFixed(1)} cm";
                            if (valor > 70.0) {
                              esCritico = true;
                            }
                          }

                          return Dismissible(
                            key: Key(estacion.id.toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (direction) async {
                              final nombreEstacion = estacion.nombre;
                              final idEliminar = estacion.id;

                              // 1. ELIMINACIÓN OPTIMISTA: Borramos de la UI instantáneamente
                              setState(() {
                                _estaciones
                                    .removeWhere((e) => e.id == idEliminar);
                              });

                              // 2. PETICIÓN AL SERVIDOR
                              bool ok =
                                  await apiService.eliminarEstacion(idEliminar);

                              if (ok) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text("$nombreEstacion eliminada")),
                                );
                              } else {
                                // Si falla el servidor, restauramos todo para avisar al usuario
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Error al eliminar del servidor")),
                                );
                                _cargarTodo();
                              }
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              color:
                                  esCritico ? Colors.red.shade50 : Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: esCritico
                                      ? Colors.red.shade100
                                      : Colors.green.shade100,
                                  child: Icon(
                                    Icons.wifi_tethering,
                                    color:
                                        esCritico ? Colors.red : Colors.green,
                                  ),
                                ),
                                title: Text(
                                  estacion.nombre,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: esCritico
                                        ? Colors.red.shade900
                                        : Colors.black87,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      "Valor actual: $valorTexto",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: esCritico
                                            ? Colors.red.shade700
                                            : Colors.blue.shade700,
                                      ),
                                    ),
                                    Text(
                                      estacion.ubicacion,
                                      style: const TextStyle(
                                          color: Colors.black54, fontSize: 13),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.black45),
                                  onPressed: () =>
                                      _mostrarDialogoEdicion(estacion),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final resultado = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEstacionScreen()),
          );
          if (resultado == true) {
            _cargarTodo();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
