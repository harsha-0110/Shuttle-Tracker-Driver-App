import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: library_prefixes
import 'package:background_location/background_location.dart' as bgLocation;

void main() {
  runApp(const MyApp());
  requestLocationPermission(); // Request location permission at the start of the application
}

void requestLocationPermission() async {
  final Location location = Location();
  final bool serviceEnabled = await location.serviceEnabled();
  if (!serviceEnabled) {
    await location.requestService();
  }
  final PermissionStatus permissionStatus = await location.requestPermission();
  if (permissionStatus != PermissionStatus.granted) {
    print('Location permission not granted.');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0a0e21),
          elevation: 5.0,
          shadowColor: Colors.black87,
          foregroundColor: Colors.white,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0a0e21),
        ),
      ),
      home: const LocationSender(),
    );
  }
}

class LocationSender extends StatefulWidget {
  const LocationSender({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LocationSenderState createState() => _LocationSenderState();
}

class _LocationSenderState extends State<LocationSender> {
  final Location _location = Location();
  bool _isSending = false;
  Timer? _timer;
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isFull = false;

  @override
  void initState() {
    super.initState();
    // Load saved values from SharedPreferences
    _loadSavedValues();

    // Initialize background location updates
    bgLocation.BackgroundLocation.startLocationService();
    bgLocation.BackgroundLocation.getLocationUpdates((locationData) {
      // Handle background location updates here
      // Remove any print statements
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _idController.dispose();
    _nameController.dispose();
    super.dispose();

    // Stop background location updates when disposing
    bgLocation.BackgroundLocation.stopLocationService();
  }

  _loadSavedValues() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _idController.text = prefs.getString('id') ?? '';
      _nameController.text = prefs.getString('name') ?? '';
      _isFull = prefs.getBool('isFull') ?? false;
    });
  }

  _saveCurrentValues() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('id', _idController.text);
    prefs.setString('name', _nameController.text);
    prefs.setBool('isFull', _isFull);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Location Sender'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextField(
                controller: _idController,
                decoration: const InputDecoration(labelText: 'ID'),
              ),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Status: ${_isFull ? 'Full' : 'Vacant'}'),
                  Switch(
                    value: _isFull,
                    onChanged: (value) {
                      setState(() {
                        _isFull = value;
                      });
                    },
                  ),
                ],
              ),
              ElevatedButton(
                onPressed:
                    _isSending ? _stopSendingLocation : _startSendingLocation,
                child: Text(_isSending
                    ? 'Stop Sending Location'
                    : 'Start Sending Location'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startSendingLocation() async {
    setState(() {
      _isSending = true;
    });

    try {
      _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) async {
        try {
          final currentLocation = await _location.getLocation();
          final id = _idController.text;
          final name = _nameController.text;

          if (id.isEmpty || name.isEmpty) {
            print('ID and Name cannot be empty.');
            return;
          }

          final Map<String, dynamic> locationData = {
            'id': id,
            'name': name,
            'latitude': currentLocation.latitude,
            'longitude': currentLocation.longitude,
            'status': _isFull ? 'Full' : 'Vacant',
          };

          final jsonLocationData = jsonEncode(locationData);

          final response = await http.post(
            Uri.parse('http://BACKEND-SERVER-URL/api/locations'),
            headers: {'Content-Type': 'application/json'},
            body: jsonLocationData,
          );

          print('Location Sent: ${response.statusCode}');
        } catch (e) {
          print('Error sending location: $e');
        }
      });
    } catch (e) {
      print('Error requesting location permission: $e');
    }
  }

  void _stopSendingLocation() {
    _saveCurrentValues();
    setState(() {
      _isSending = false;
    });
    _timer?.cancel();
  }
}
