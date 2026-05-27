import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/estacion.dart';
import 'auth_service.dart';

class ApiService {
  // Nota: 10.0.2.2 es el localhost para el emulador Android.
  // Si usa Linux Desktop o Web, use 'localhost'.
  final String baseUrl = "http://127.0.0.1:8000";

  Future<List<Estacion>> fetchEstaciones() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/estaciones/'))
          .timeout(const Duration(seconds: 5)); // Evita esperas infinitas
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse.map((data) => Estacion.fromJson(data)).toList();
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
// Esto evita que la App se cierre inesperadamente
      throw Exception(
          'No se pudo conectar con SMAT. ¿Está el servidor activo?');
    }
  }

  Future<bool> crearEstacion(String nombre, String ubicacion) async {
    final token = await AuthService().getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/estaciones/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'nombre': nombre, 'ubicacion': ubicacion}),
    );
    return response.statusCode == 200;
  }

  //eliminar una estacion
  Future<bool> eliminarEstacion(int id) async {
    final token = await AuthService().getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/estaciones/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200;
  }

  //actualizar una estacion
  Future<bool> editarEstacion(int id, String nombre, String ubicacion) async {
    final token = await AuthService().getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/estaciones/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'nombre': nombre, 'ubicacion': ubicacion}),
    );
    return response.statusCode == 200;
  }

  Future<List<dynamic>> fetchLecturas() async {
    try {
      // 1. Recuperamos el token almacenado de forma segura al iniciar sesión
      final token = await AuthService().getToken();

      // 2. Hacemos el GET inyectando el Bearer token en las cabeceras
      final response = await http.get(
        Uri.parse('$baseUrl/lecturas/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer $token', // <--- ¡La llave para solucionar el 401!
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // Decodificamos la respuesta JSON (que ahora sí traerá los datos)
        List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse;
      } else {
        print(
            "El backend rechazó la solicitud. Código de estado: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error al conectar con /lecturas/: $e");
      return []; // Devolvemos una lista vacía si falla la conexión
    }
  }
}
