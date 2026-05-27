import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/estacion.dart';
import 'login_screen.dart';
import 'add_estacion.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Variable para almacenar el Future de la petición API
  late Future<List<Estacion>> _futureEstaciones;

  @override
  void initState() {
    super.initState();
    _obtenerEstaciones(); // Inicializa la carga al arrancar el widget
  }

  // Método centralizado para cargar o refrescar los datos
  void _obtenerEstaciones() {
    setState(() {
      _futureEstaciones = ApiService().fetchEstaciones();
    });
  }

  // Función para cerrar sesión
  void _logout() async {
    await AuthService().logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // Diálogo de Edición
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
              decoration: const InputDecoration(labelText: "Nombre"),
            ),
            TextField(
              controller: ubicacionCtrl,
              decoration: const InputDecoration(labelText: "Ubicación"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              bool ok = await ApiService().editarEstacion(
                  estacion.id, nombreCtrl.text, ubicacionCtrl.text);
              if (ok) {
                Navigator.pop(context);
                _obtenerEstaciones(); // Refresca la lista de forma limpia
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
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<List<Estacion>>(
        future: _futureEstaciones, // Escucha la variable controlada del estado
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            // Manejo seguro cuando el backend devuelve una lista vacía
            return RefreshIndicator(
              onRefresh: () async => _obtenerEstaciones(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 100),
                  Center(child: Text('No hay estaciones disponibles.')),
                ],
              ),
            );
          }

          final estaciones = snapshot.data!;

          // Reto: Pull-to-Refresh optimizado
          return RefreshIndicator(
            onRefresh: () async => _obtenerEstaciones(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: estaciones.length,
              itemBuilder: (context, index) {
                final estacion = estaciones[index];

                // Gesto de deslizar para borrar
                return Dismissible(
                  key: Key(estacion.id.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) async {
                    bool ok = await ApiService().eliminarEstacion(estacion.id);
                    if (ok) {
                      _obtenerEstaciones(); // Sincroniza estado con el backend de inmediato
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Estación "${estacion.nombre}" eliminada'),
                        ),
                      );
                    }
                  },
                  child: ListTile(
                    // Reto: Lógica de Colores (Alerta Temprana)
                    leading: Icon(
                      Icons.sensors,
                      color: (estacion.valor > 50) ? Colors.red : Colors.green,
                    ),
                    title: Text(estacion.nombre),
                    subtitle: Text(
                        "Valor actual: ${estacion.valor} | ${estacion.ubicacion}"),
                    onTap: () => _mostrarDialogoEdicion(estacion),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          bool? refresh = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEstacionScreen()),
          );
          if (refresh == true) {
            _obtenerEstaciones(); // Recarga la lista si se añadió un elemento
          }
        },
      ),
    );
  }
}
