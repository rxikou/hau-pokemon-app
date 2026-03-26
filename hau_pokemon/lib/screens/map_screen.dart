import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:torch_light/torch_light.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/monster.dart';
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

  bool _isLoadingMonsters = true;
  List<Monster> _monsters = const [];

  Future<void> _showDetectedMonstersDialog({
    required Position playerPosition,
    required List<({Monster monster, double distanceMeters})> detected,
  }) async {
    if (!mounted) return;

    detected.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    int selectedIndex = 0;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final selected = detected[selectedIndex];

            String formatMeters(double meters) {
              if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
              return '${meters.toStringAsFixed(0)} m';
            }

            Widget buildRow(String label, String value) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(child: Text(value)),
                  ],
                ),
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                detected.length == 1 ? 'Monster Detected' : 'Monsters Detected',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildRow('Your GPS',
                        '${playerPosition.latitude.toStringAsFixed(6)}, ${playerPosition.longitude.toStringAsFixed(6)}'),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: detected.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = detected[index];
                          final isSelected = index == selectedIndex;
                          return Material(
                            color: isSelected
                                ? scheme.primary.withValues(alpha: 25)
                                : scheme.surfaceContainerHighest.withValues(alpha: 60),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setStateDialog(() => selectedIndex = index),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.monster.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${entry.monster.type} • Distance: ${formatMeters(entry.distanceMeters)} • Radius: ${formatMeters(entry.monster.radius)}',
                                            style: TextStyle(color: scheme.onSurfaceVariant),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Spawn: ${entry.monster.lat.toStringAsFixed(6)}, ${entry.monster.lng.toStringAsFixed(6)}',
                                            style: TextStyle(color: scheme.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    buildRow('Selected', selected.monster.name),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _triggerHardwareAlert();
                    _showSuccessDialog(selected.monster.name);
                  },
                  child: const Text('Catch', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _fetchMonsters();
  }

  Future<void> _fetchMonsters() async {
    setState(() => _isLoadingMonsters = true);
    try {
      final monsters = await _apiService.getMonsters();
      if (!mounted) return;
      setState(() {
        _monsters = monsters;
        _isLoadingMonsters = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMonsters = false);
      _showSnackBar(e is ApiException ? e.toString() : 'Failed to load monsters.');
    }
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

  // 2. Detect/Catch Logic (LOCAL)
  Future<void> _attemptCatch() async {
    if (currentPosition == null || _isDetecting) return;

    setState(() { _isDetecting = true; });
    _showSnackBar('Scanning area for monsters...');

    // Fetch the absolute latest coordinates before sending to AWS
    Position latestPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    if (!mounted) return;
    setState(() {
      currentPosition = latestPosition;
    });

    // If monsters are still loading or none exist, bail early.
    if (_isLoadingMonsters) {
      setState(() { _isDetecting = false; });
      _showSnackBar('Monsters are still loading. Please try again.');
      return;
    }

    if (_monsters.isEmpty) {
      setState(() { _isDetecting = false; });
      _showSnackBar('No monsters available. Add monsters first.');
      return;
    }

    final detected = <({Monster monster, double distanceMeters})>[];
    for (final m in _monsters) {
      final distanceMeters = Geolocator.distanceBetween(
        latestPosition.latitude,
        latestPosition.longitude,
        m.lat,
        m.lng,
      );
      if (distanceMeters <= m.radius) {
        detected.add((monster: m, distanceMeters: distanceMeters));
      }
    }

    setState(() { _isDetecting = false; });

    if (detected.isNotEmpty) {
      await _showDetectedMonstersDialog(
        playerPosition: latestPosition,
        detected: detected,
      );
    } else {
      _showSnackBar('No monsters nearby. Move closer to a spawn area.');
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

    final markers = <Marker>{};
    final circles = <Circle>{};

    for (final m in _monsters) {
      final markerId = 'monster_${m.id ?? m.name}_${m.lat}_${m.lng}';
      markers.add(
        Marker(
          markerId: MarkerId(markerId),
          position: LatLng(m.lat, m.lng),
          infoWindow: InfoWindow(title: m.name, snippet: '${m.type} • ${m.radius.toStringAsFixed(0)}m'),
        ),
      );

      circles.add(
        Circle(
          circleId: CircleId('circle_$markerId'),
          center: LatLng(m.lat, m.lng),
          radius: m.radius,
          fillColor: scheme.primary.withValues(alpha: 60),
          strokeColor: scheme.primary.withValues(alpha: 180),
          strokeWidth: 1,
        ),
      );
    }

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
                markers: markers,
                circles: circles,
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