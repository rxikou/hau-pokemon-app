import 'dart:async';
import 'dart:math' as math;

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

class MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  GoogleMapController? mapController;
  Position? currentPosition;
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final AnimationController _scanRippleController;
  bool _isDetecting = false; // Prevents spam-clicking the detect button

  bool _isLoadingMonsters = true;
  List<Monster> _monsters = const [];

  Future<void> _catchSelectedMonster({
    required Monster selectedMonster,
    required Position playerPosition,
  }) async {
    _showSnackBar('Catching ${selectedMonster.name}...');

    final result = await _apiService.catchMonster(
      widget.playerId,
      playerPosition.latitude,
      playerPosition.longitude,
      monsterId: selectedMonster.id,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      _showSuccessDialog(
        (result['monster_name'] ?? selectedMonster.name).toString(),
        locationName: (result['location_name'] ?? '').toString(),
      );
      // Run hardware effects in the background so success feedback is instant.
      unawaited(_triggerHardwareAlert());
    } else {
      _showSnackBar((result['message'] ?? 'Failed to catch monster.').toString());
    }
  }

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
                          final bgColor = isSelected
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHighest.withValues(alpha: 90);
                          final titleColor =
                              isSelected ? scheme.onPrimaryContainer : scheme.onSurface;
                          final subtitleColor = isSelected
                              ? scheme.onPrimaryContainer.withValues(alpha: 204)
                              : scheme.onSurfaceVariant;
                          return Material(
                            color: bgColor,
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
                                      color: isSelected
                                          ? scheme.onPrimaryContainer
                                          : scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.monster.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: titleColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${entry.monster.type} • Distance: ${formatMeters(entry.distanceMeters)} • Radius: ${formatMeters(entry.monster.radius)}',
                                            style: TextStyle(color: subtitleColor),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Spawn: ${entry.monster.lat.toStringAsFixed(6)}, ${entry.monster.lng.toStringAsFixed(6)}',
                                            style: TextStyle(color: subtitleColor),
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
                  onPressed: () async {
                    final chosen = selected.monster;
                    Navigator.of(context).pop();
                    await _catchSelectedMonster(
                      selectedMonster: chosen,
                      playerPosition: playerPosition,
                    );
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
    _scanRippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
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
    _scanRippleController.repeat();
    _showSnackBar('Scanning area for monsters...');

    try {
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
        _showSnackBar('Monsters are still loading. Please try again.');
        return;
      }

      if (_monsters.isEmpty) {
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

      if (detected.isNotEmpty) {
        // Keep radar visible briefly so scanning feels intentional.
        await Future.delayed(const Duration(milliseconds: 1500));
        await _showDetectedMonstersDialog(
          playerPosition: latestPosition,
          detected: detected,
        );
      } else {
        _showSnackBar('No monsters nearby. Move closer to a spawn area.');
      }
    } finally {
      if (mounted) {
        _scanRippleController.stop();
        _scanRippleController.reset();
        setState(() { _isDetecting = false; });
      }
    }
  }

  Widget _buildScanRippleOverlay(Color color) {
    const radarColor = Color(0xFF39FF14);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _scanRippleController,
        builder: (context, _) {
          final t = _scanRippleController.value;
          return Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int i = 0; i < 3; i++)
                  Builder(
                    builder: (_) {
                      final phase = ((t + (i / 3)) % 1.0);
                      final size = 90 + (phase * 230);
                      final alpha = (1 - phase) * 0.90;
                      return Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: radarColor.withValues(alpha: alpha),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.transparent, width: 0),
                  ),
                  child: Transform.rotate(
                    angle: t * math.pi * 2,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: _RadarPokeball(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 3. Hardware Triggers (Rubric Requirement)
  Future<void> _triggerHardwareAlert() async {
    try {
      // Trigger sound and torch in parallel for faster feedback.
      final soundFuture = _audioPlayer.play(AssetSource('alarm.mp3'));

      final torchFuture = () async {
        final hasTorch = await TorchLight.isTorchAvailable();
        if (!hasTorch) return;

        await TorchLight.enableTorch();
        await Future.delayed(const Duration(milliseconds: 1200));
        await TorchLight.disableTorch();
      }();

      await Future.wait([
        soundFuture,
        torchFuture,
      ]);
    } catch (e) {
      debugPrint("Hardware trigger error: $e");
    }
  }

  // UI Helpers
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessDialog(String monsterName, {String? locationName}) {
    final place = (locationName != null && locationName.trim().isNotEmpty)
        ? ' at ${locationName.trim()}'
        : '';

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
        content: Text(
          "Incredible! You just caught a $monsterName$place!",
          style: const TextStyle(fontSize: 16),
        ),
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
          // Keep gameplay radius unchanged in logic, but render a little smaller/softer for clarity.
          radius: (m.radius * 0.82).clamp(20.0, 3000.0).toDouble(),
          fillColor: scheme.primary.withValues(alpha: 0.25),
          strokeColor: scheme.primary.withValues(alpha: 0.65),
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

          if (_isDetecting) _buildScanRippleOverlay(const Color(0xFF39FF14)),
              
          // The "Detect" Action Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30.0, left: 20, right: 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isDetecting ? scheme.surfaceContainerHighest : scheme.primary,
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _isDetecting ? null : _attemptCatch,
                  icon: _isDetecting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.radar, size: 22, color: Colors.white),
                  label: Text(
                    _isDetecting ? "Scanning..." : "Detect Monsters", 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8),
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
    _scanRippleController.dispose();
    mapController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}

class _RadarPokeball extends StatelessWidget {
  const _RadarPokeball();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RadarPokeballPainter(),
    );
  }
}

class _RadarPokeballPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const outline = Colors.black;
    const topRed = Color(0xFFE53935);

    final strokeWidth = size.width * 0.10;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final clip = Path()..addOval(rect);

    final borderPaint = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.save();
    canvas.clipPath(clip);
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height / 2),
      Paint()..color = topRed,
    );

    final bandRect = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: size.height * 0.14,
    );
    canvas.drawRect(bandRect, Paint()..color = outline);
    canvas.drawCircle(center, size.width * 0.17, Paint()..color = outline);
    canvas.drawCircle(center, size.width * 0.09, Paint()..color = Colors.white);
    canvas.restore();

    canvas.drawCircle(center, radius - (strokeWidth / 2), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPokeballPainter oldDelegate) => false;
}