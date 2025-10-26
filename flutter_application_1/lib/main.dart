import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert'; // <- asegúrate arriba del archivo


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
  final String espHost = 'alarmaesp.local'; // <- cambia por la IP real del ESP32
  final String token = 'miToken123'; // <- debe coincidir con el token en el ESP
  final Duration timeout = Duration(seconds: 20);

  bool _isConnected = false; // <-- luego lo vas a actualizar con _getStatus()
  bool detectionEnabled = true; // o false según estado inicial real
  String _espSsid = "";
  String _phoneSaved = ""; // <- se llenará luego




  bool showForm = false;

  bool _loading = false;

  // Helper: mostrar feedback rápido
  void _showMsg(String msg) {
    debugPrint(msg); // salida por consola segura para Flutter
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: Duration(seconds: 2)),
    );
  }
  
  Future<bool> _sendPost(String path) async {
    setState(() => _loading = true);
    final uri = Uri.parse('http://$espHost$path');

    try {
      final response = await http.post(uri).timeout(timeout);

      if (response.statusCode == 200) {
        _showMsg('OK: ${response.body}');
        return true; // <<< ESTA ES LA CLAVE
      } else {
        _showMsg('Error ${response.statusCode}: ${response.body}');
        return false;
      }
    } on TimeoutException {
      _showMsg('Timeout: el ESP32 no respondió');
      return false;
    } catch (e) {
      _showMsg('Error conexión: $e');
      return false;
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

  Future<void> _getStatus() async {
  final uri = Uri.parse('http://$espHost/status');
  try {
    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      setState(() {
        _isConnected = data["wifi_ok"] ?? false;
        _espSsid     = data["wifi_ssid"] ?? "";
        detectionEnabled = data["deteccionActiva"] ?? false;
        _phoneSaved  = data["phoneNumber"] == null ? "" : data["phoneNumber"];
      });

      _showMsg("Estado actualizado");
    } else {
      _showMsg("Error ${response.statusCode}");
    }
  } catch (e) {
    _showMsg("No se pudo obtener estado: $e");
  }
}
  Future<void> openWhatsapp() async {
    const String phoneNumber = '+34694264806';
    const String message = 'I allow callmebot to send me messages';

    final Uri url = Uri.parse(
        'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication, // <--- IMPORTANTE
      );
    } else {
      throw 'No se pudo abrir WhatsApp';
    }
  }

  //TOGLERS------------------------------

  Future<void> _toggleDetection() async {
    // Si está activa → vamos a detener
    final String path = detectionEnabled ? '/detener' : '/activar';

    final ok = await _sendPost(path);

    // Solo cambiar UI si el ESP respondió OK (status 200)
    if (ok) {
      setState(() {
        detectionEnabled = !detectionEnabled;
      });
    }
  }

  

  // Funciones específicas para cada botón
  Future<void> _changeWifi() async {
    // en el sketch de ejemplo, /cambiarwifi es GET
    await _sendGet('/cambiarwifi');
  }

  Future<void> _disableAlarm() async {
    await _sendPost('/apagar'); // en el sketch /apagar espera POST
  }

  // ------ VENTANAS EMERGENTES ------

  void _showPhoneDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Número WhatsApp"),
      content: Text(
        _phoneSaved.isEmpty
          ? "No hay un número configurado."
          : "Numero configurado: $_phoneSaved",
      ),
      actions: [
        TextButton(
          child: Text("Cerrar"),
          onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }


  void _showAboutDialog() {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text("Expofisica 2025"),
        content: Text("SecurityQuilla Team:\n\n- David Caceres \n- Wilmar Fontalvo \n- Juan Martin \n- Enrique Peinado \n- Eliud Quiroz \n- Neithan Torres \n- Yader Vega"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cerrar"),
          ),
        ],
      );
    },
  );
}

 void _showWifiInfo() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Estado de conexión"),
      content: Text(_isConnected
          ? "✅ Conectado al ESP32 en la red WiFi: $_espSsid"
          : "❌ No hay comunicacion con el ESP32"),
      actions: [
        TextButton(
          child: Text("Cerrar"),
          onPressed: () => Navigator.pop(context),
        )
      ],
    ),
  );
}

 Future<void> showConfigDialog() async {
  final _numCtrl = TextEditingController();
  final _apiCtrl = TextEditingController();

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          // <-- esto sube el contenido cuando aparece teclado
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Enviar datos al ESP32", style: TextStyle(fontSize: 18)),
            SizedBox(height: 16),
            TextField(
              controller: _numCtrl,
              decoration: InputDecoration(
                labelText: "Ingresa tu número",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _apiCtrl,
              decoration: InputDecoration(
                labelText: "Ingresa tu apikey",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final d1 = Uri.encodeComponent(_numCtrl.text);
                    final d2 = Uri.encodeComponent(_apiCtrl.text);
                    await _sendGet("/config?dato1=$d1&dato2=$d2");
                    Navigator.pop(context);
                  },
                  child: Text("Enviar"),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}


@override
void initState() {
  super.initState();
  _getStatus();   // << SE EJECUTA APENAS ABRE LA APP
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white), // color del icono
        centerTitle: false,
        title: const Text(
          'SecurityQuilla',
          style: TextStyle(
            color: Colors.white, // <-- color del texto
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Roboto', // Opcional
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 19, 50, 138),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
           // --- ICONO DEL NUEVO CONTACTO ---
            IconButton(
              icon: Icon(Icons.contact_phone),
              onPressed: _showPhoneDialog,
            ),
            // --- ICONO DEL WIFI ---
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
            icon: Icon(_isConnected ? Icons.wifi : Icons.wifi_off),
            onPressed: _showWifiInfo,
          ),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            // ---- HEADER ----
            Container(
              height: 140,
              color: Color.fromARGB(255, 19, 50, 138),
              child: Center(
                child: Icon(Icons.shield, color: Colors.white, size: 60),
              ),
            ),

            // ---- OPCIONES PRINCIPALES ----
            ListTile(
              leading: Icon(Icons.wifi),
              title: Text("Cambiar WiFi"),
              onTap: _changeWifi,
            ),ListTile(
              leading: Icon(Icons.chat),
              title: Text("Configurar WhatsApp"),
              onTap: () async {
                await openWhatsapp();
                Navigator.pop(context);
                await showConfigDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.update),
              title: Text("Actualizar estado"),
              onTap: _getStatus,
            ),

            Spacer(), // <-- EMPUJA LO SIGUIENTE AL FONDO

            // ---- OPCIONES ABAJO ----
            ListTile(
              leading: Icon(Icons.info_outline),
              title: Text("Sobre nosotros"),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.menu_book_outlined),
              title: Text("Ver guía inicial"),
              onTap: () {
                Navigator.pop(context);
                // aquí luego llamaremos al onboarding
              },
            ),
            SizedBox(height: 10),
          ],
        ),
      ),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  // Indicador circular
                  Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: !_isConnected
                            ? Colors.grey      // <<< si no hay conexión
                            : detectionEnabled
                                ? Colors.green // conectado y activo
                                : Colors.red,  // conectado y detenido
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        !_isConnected
                            ? Icons.help       // ícono distinto si no hay conexión
                            : detectionEnabled
                                ? Icons.visibility
                      : Icons.visibility_off,
                      size: 70,
                      color: Colors.white,
              ),
        ),

                  SizedBox(height: 20),
                  Text(
                    !_isConnected
                        ? "Sin conexión"
                        : detectionEnabled
                            ? "Detección ACTIVA"
                            : "Detección DETENIDA",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 30),
                  // Botón toggle
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(
                        detectionEnabled ? Icons.pause : Icons.play_arrow,
                        size: 28,
                        color: (_loading || !_isConnected)
                            ? Colors.grey  // <-- gris si no funciona
                            : Colors.white,
                      ),

                      label: Text(
                        detectionEnabled ? "Desactivar detección" : "Activar detección",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      onPressed: (_loading || !_isConnected) ? null : _toggleDetection,

                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // === BLOQUE DE ALARMA ===
              Column(
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(

                      color: !_isConnected
                            ? Colors.grey      // <<< si no hay conexión
                            : Colors.orange, // conectado y activo
                   
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 70,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    _isConnected ? " Alarma" : "Sin conexión",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(Icons.notifications_off, size: 28),
                      label: Text(
                        "Desactivar alarma",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      onPressed: (_loading || !_isConnected) ? null : _disableAlarm,
                    ),
                  ),
                ],
              ),
              if (_loading) CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}