class Estacion {
  final int id;
  final String nombre;
  final String ubicacion;
  final int? ultimaLectura;
  Estacion(
      {required this.id,
      required this.nombre,
      required this.ubicacion,
      this.ultimaLectura});

  factory Estacion.fromJson(Map<String, dynamic> json) {
    return Estacion(
      id: json['id'],
      nombre: json['nombre'],
      ubicacion: json['ubicacion'],
      ultimaLectura: json['ultima_lectura'] ??
          json['lectura'] ??
          0, // Valor por defecto si no viene en el JSON
    );
  }
}
