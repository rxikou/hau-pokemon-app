import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../models/monster.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';

class AddMonsterScreen extends StatefulWidget {
  const AddMonsterScreen({super.key});

  @override
  State<AddMonsterScreen> createState() => _AddMonsterScreenState();
}

class _AddMonsterScreenState extends State<AddMonsterScreen> {
  final ApiService _apiService = ApiService();

  // Form Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _radiusController =
      TextEditingController(text: "100");

  // Map & Location State
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  double _currentRadius = 100.0;

  // Image State
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _nameController.dispose();
    _typeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  // 1. Get current location to center the map initially
  Future<void> _setInitialLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation!, 16),
      );
    } catch (e) {
      debugPrint("Could not get initial location: $e");
    }
  }

  // 2. Handle Map Taps to drop a pin
  void _onMapTapped(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  // 3. Image Picker Logic
  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile =
        await _picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // 4. Save Logic
  Future<void> _saveMonster() async {
    if (_nameController.text.isEmpty ||
        _typeController.text.isEmpty ||
        _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select a location.'),
        ),
      );
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    final radius = double.tryParse(_radiusController.text) ?? _currentRadius;
    final monster = Monster(
      name: _nameController.text.trim(),
      type: _typeController.text.trim(),
      lat: _selectedLocation!.latitude,
      lng: _selectedLocation!.longitude,
      radius: radius,
      // NOTE: photo is currently local-only; not uploaded.
    );

    try {
      final ok = await _apiService.createMonster(monster);
      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${monster.name} saved successfully!')),
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save monster.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Define the map markers and circles dynamically
    final Set<Marker> markers = {};
    final Set<Circle> circles = {};

    if (_selectedLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('spawn_point'),
          position: _selectedLocation!,
        ),
      );
      circles.add(
        Circle(
          circleId: const CircleId('spawn_radius'),
          center: _selectedLocation!,
          radius: _currentRadius,
          fillColor: scheme.primary.withValues(alpha: 77),
          strokeColor: scheme.primary,
          strokeWidth: 1,
        ),
      );
    }

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Add Monster'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _setInitialLocation,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Form Fields
            _buildTextField(_nameController, 'Monster Name'),
            const SizedBox(height: 12),
            _buildTextField(_typeController, 'Monster Type'),
            const SizedBox(height: 12),
            _buildTextField(
              _radiusController,
              'Spawn Radius (meters)',
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _currentRadius = double.tryParse(value) ?? 100.0;
                });
              },
            ),
            const SizedBox(height: 20),

            // Interactive Map
            Container(
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outline.withValues(alpha: 51)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _selectedLocation == null
                    ? const Center(child: CircularProgressIndicator())
                    : GoogleMap(
                        initialCameraPosition:
                            CameraPosition(target: _selectedLocation!, zoom: 16),
                        onMapCreated: (controller) => _mapController = controller,
                        onTap: _onMapTapped,
                        markers: markers,
                        circles: circles,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                      ),
              ),
            ),

            // Location Instructions & Data
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                children: [
                  const Text(
                    'Tap on the map to set the monster spawn point',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedLocation != null) ...[
                    Text('Latitude: ${_selectedLocation!.latitude.toStringAsFixed(6)}'),
                    Text('Longitude: ${_selectedLocation!.longitude.toStringAsFixed(6)}'),
                    Text('Radius: $_currentRadius meters'),
                  ]
                ],
              ),
            ),

            // Image Preview
            if (_imageFile != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_imageFile!, height: 150, fit: BoxFit.cover),
                ),
              ),

            // Photo Buttons
            OutlinedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture Photo'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () => _pickImage(ImageSource.camera),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Pick from Gallery'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveMonster,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save Monster',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Helper method to keep text fields clean and consistent
  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
      ),
    );
  }
}
