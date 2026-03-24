import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/monster.dart';
import '../services/api_service.dart';

class EditMonsterScreen extends StatefulWidget {
  final Monster monster; // The monster we are editing

  const EditMonsterScreen({super.key, required this.monster});

  @override
  State<EditMonsterScreen> createState() => _EditMonsterScreenState();
}

class _EditMonsterScreenState extends State<EditMonsterScreen> {
  final ApiService _apiService = ApiService();

  // Form Controllers
  late TextEditingController _nameController;
  late TextEditingController _typeController;
  late TextEditingController _radiusController;

  // Map State
  GoogleMapController? _mapController;
  late LatLng _selectedLocation;
  late double _currentRadius;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill the form with the existing monster's data
    _nameController = TextEditingController(text: widget.monster.name);
    _typeController = TextEditingController(text: widget.monster.type);
    _radiusController =
        TextEditingController(text: widget.monster.radius.toString());

    _selectedLocation = LatLng(widget.monster.lat, widget.monster.lng);
    _currentRadius = widget.monster.radius;
  }

  // Handle Map Taps to move the spawn point
  void _onMapTapped(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  // Update Logic
  Future<void> _updateMonster() async {
    if (_nameController.text.isEmpty || _typeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields.')),
      );
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    final radius = double.tryParse(_radiusController.text) ?? _currentRadius;
    final updated = widget.monster.copyWith(
      name: _nameController.text.trim(),
      type: _typeController.text.trim(),
      lat: _selectedLocation.latitude,
      lng: _selectedLocation.longitude,
      radius: radius,
    );

    try {
      final ok = await _apiService.updateMonster(updated);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${updated.name} updated successfully!')),
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
        const SnackBar(content: Text('Failed to update monster.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('spawn_point'),
        position: _selectedLocation,
      )
    };

    final Set<Circle> circles = {
      Circle(
        circleId: const CircleId('spawn_radius'),
        center: _selectedLocation,
        radius: _currentRadius,
        fillColor: scheme.primary.withValues(alpha: 77),
        strokeColor: scheme.primary,
        strokeWidth: 1,
      )
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Monster'),
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
                  _currentRadius = double.tryParse(value) ?? _currentRadius;
                });
              },
            ),
            const SizedBox(height: 20),

            // Interactive Map
            Container(
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: _selectedLocation, zoom: 16),
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

            // Location Data Text (Matches your screenshot)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  Text('Latitude: ${_selectedLocation.latitude.toStringAsFixed(6)}'),
                  Text('Longitude: ${_selectedLocation.longitude.toStringAsFixed(6)}'),
                  Text('Radius: ${_currentRadius.toStringAsFixed(2)} meters'),
                ],
              ),
            ),

            // Update Button
            ElevatedButton(
              onPressed: _isSaving ? null : _updateMonster,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Update Monster',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }

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

  @override
  void dispose() {
    _mapController?.dispose();
    _nameController.dispose();
    _typeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }
}
