import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:torch_light/torch_light.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';

class MapScreen extends StatefulWidget {
  final int playerId; // Passed in from your Auth/Dashboard screens
  
  const MapScreen({super.key, required this.playerId});

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  Position? currentPosition;
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isDetecting = false; // Prevents spam-clicking the detect button

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  // 1. Request Permissions & Get Live GPS
  Future<void> _initializeLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled. Please enable them.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permissions are denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permissions are permanently denied.');
      return;
    }

    // Get the initial position
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    setState(() {
      currentPosition = position;
    });

    // Move the map camera to the user
    mapController?.animateCamera(CameraUpdate.newLatLngZoom(
      LatLng(position.latitude, position.longitude), 
      17.0, // A nice close-up zoom level
    ));
  }

  // 2. The Core Catch Logic
  Future<void> _attemptCatch() async {
    if (currentPosition == null || _isDetecting) return;

    setState(() { _isDetecting = true; });
    _showSnackBar('Scanning area for monsters...');

    // Fetch the absolute latest coordinates before sending to AWS
    Position latestPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    // Call the Python API over the Tailscale VPN
    final result = await _apiService.catchMonster(
      widget.playerId, 
      latestPosition.latitude, 
      latestPosition.longitude
    );

    setState(() { _isDetecting = false; });

    if (result['success'] == true) {
      _triggerHardwareAlert();
      _showSuccessDialog(result['monster_name']);
    } else {
      _showSnackBar(result['message'] ?? 'No monsters nearby. Keep hunting!');
    }
  }

  // 3. Hardware Triggers (Rubric Requirement)
  Future<void> _triggerHardwareAlert() async {
    try {
      // Play the alarm sound
      await _audioPlayer.play(AssetSource('alarm.mp3'));
      
      // Flash the camera torch for 5 seconds
      bool hasTorch = await TorchLight.isTorchAvailable();
      if (hasTorch) {
        await TorchLight.enableTorch();
        await Future.delayed(const Duration(seconds: 5));
        await TorchLight.disableTorch();
      }
    } catch (e) {
      debugPrint("Hardware trigger error: $e");
    }
  }

  // UI Helpers
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessDialog(String monsterName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.stars, color: Colors.amber, size: 30),
            SizedBox(width: 10),
            Text("Monster Caught!"),
          ],
        ),
        content: Text("Incredible! You just caught a $monsterName!", style: const TextStyle(fontSize: 16)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context), 
            child: const Text("Awesome", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: AppDrawer(playerId: widget.playerId),
      appBar: AppBar(title: const Text("Monster Map")),
      body: Stack(
        children: [
          // The Google Map Layer
          currentPosition == null 
            ? Center(child: CircularProgressIndicator(color: scheme.primary))
            : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
                  zoom: 17.0,
                ),
                myLocationEnabled: currentPosition != null, // Shows the blue dot when permitted
                myLocationButtonEnabled: true, // Adds the "center me" button
                mapToolbarEnabled: false,
                onMapCreated: (GoogleMapController controller) {
                  mapController = controller;
                },
              ),
              
          // The "Detect" Action Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30.0, left: 20, right: 20),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isDetecting ? scheme.surfaceContainerHighest : scheme.primary,
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _isDetecting ? null : _attemptCatch,
                  icon: _isDetecting 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.radar, size: 28, color: Colors.white),
                  label: Text(
                    _isDetecting ? "Scanning..." : "Detect Monsters", 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    mapController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}