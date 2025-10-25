import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

void main() {
  runApp(const SecurityQuillaApp());
}

class SecurityQuillaApp extends StatelessWidget {
  const SecurityQuillaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecurityQuilla',
      home: SecurityQuillaHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SecurityQuillaHome extends StatefulWidget {
  const SecurityQuillaHome({super.key});

  @override
  State<SecurityQuillaHome> createState() => _SecurityQuillaHomeState();
}

class _SecurityQuillaHomeState extends State<SecurityQuillaHome> {
  // --- CONFIGURA ESTAS VARIABLES ---
  final String espHost = 'alarmaesp.local';     // <- cambia por la IP real del ESP32
  final String token = 'miToken123';       // <- debe coincidir con el token en el ESP
  final Duration timeout = Duration(seconds: 20);

  bool _loading = false;

  // Helper: mostrar feedback rápido
  void _showMsg(String msg) {
    debugPrint(msg); // salida por consola segura para Flutter
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: Duration(seconds: 2)),
    );
  }
 Future<void> _sendPost(String path) async {
  setState(() => _loading = true);
  final uri = Uri.parse('http://$espHost$path');
  try {
    final response = await http
        .post(
          uri,
          headers: {
            'X-Auth': token,
            'Connection': 'close',
          },
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      _showMsg('OK: ${response.body}');
    } else {
      _showMsg('Error ${response.statusCode}: ${response.body}');
    }
  } on TimeoutException {
    _showMsg('Timeout: el ESP32 no respondió');
  } catch (e) {
    String msg = 'Error desconocido';
    if (e.toString().contains('Connection refused')) {
      msg = 'El ESP32 rechazó la conexión (posiblemente no está escuchando)';
    } else if (e.toString().contains('No route to host')) {
      msg = 'No hay ruta al ESP32 (puede no estar en la misma red WiFi)';
    } else if (e.toString().contains('Failed host lookup')) {
      msg = 'No se pudo resolver la IP del ESP32';
    } else {
      msg = 'Error conexión: $e';
    }
    _showMsg(msg);
  } finally {
    setState(() => _loading = false);
  }
}





  Future<void> _sendGet(String path) async {
  setState(() => _loading = true);
  final uri = Uri.parse('http://$espHost$path');
  try {
    final response = await http
        .get(
          uri,
          headers: {'X-Auth': token},
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      _showMsg('OK: ${response.body}');
    } else {
      _showMsg('Error ${response.statusCode}: ${response.body}');
    }
  } on TimeoutException {
    _showMsg('Timeout: el ESP32 no respondió');
  } catch (e) {
    String msg = 'Error desconocido';
    if (e.toString().contains('Connection refused')) {
      msg = 'El ESP32 rechazó la conexión (posiblemente no está escuchando)';
    } else if (e.toString().contains('No route to host')) {
      msg = 'No hay ruta al ESP32 (puede no estar en la misma red WiFi)';
    } else if (e.toString().contains('Failed host lookup')) {
      msg = 'No se pudo resolver la IP del ESP32';
    } else {
      msg = 'Error conexión: $e';
    }
    _showMsg(msg);
  } finally {
    setState(() => _loading = false);
  }
}

Future<void> openWhatsapp() async {
  const String phoneNumber = '+34694264806'; // Reemplaza con el número de teléfono
  const String message = 'I allow callmebot to send me messages';
  final Uri url = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');

  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  } else {
    throw 'No se pudo abrir WhatsApp. ¿Está instalado en el dispositivo?';
  }
}

  // Funciones específicas para cada botón
  Future<void> _changeWifi() async {
    // en el sketch de ejemplo, /cambiarwifi es GET
    await _sendGet('/cambiarwifi');
  }

  Future<void> _disableDetection() async {
    await _sendPost('/detener'); // en el sketch /detener espera POST
  }

  Future<void> _disableAlarm() async {
    await _sendPost('/apagar'); // en el sketch /apagar espera POST
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SecurityQuilla'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _loading ? null : _changeWifi,
                child: Text('Cambiar WiFi'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _disableDetection,
                child: Text('Desactivar Detección'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _disableAlarm,
                child: Text('Desactivar Alarma'),
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: _loading ? null : openWhatsapp,
                child: Text('Contactar por WhatsApp'),
              ),
              SizedBox(height: 30),
              if (_loading) CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}