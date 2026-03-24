import 'package:flutter/material.dart';

import '../widgets/app_drawer.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('About Us'),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // App Logo / Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 26),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.catching_pokemon, size: 80, color: scheme.primary),
              ),
              const SizedBox(height: 24),
              
              // App Title & Version
              const Text(
                'HAUPokemon Engine', 
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 128),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Version 1.0.0-Release', 
                  style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 32),
              
              // Architecture Description
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'This application demonstrates a highly secure cloud infrastructure utilizing AWS VPC Peering, a Zero-Trust Tailscale VPN network, and real-time GPS Haversine processing for location-based monster hunting.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              const Divider(),
              const SizedBox(height: 20),
              
              // Developer Credits
              const Text(
                'LEAD DEVELOPER', 
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)
              ),
              const SizedBox(height: 12),
              Text(
                'Seane Karl S. Garcia', 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: scheme.primary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cloud Architecture & Mobile App Integration',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}