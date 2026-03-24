import 'package:flutter/material.dart';

import '../services/ec2_service.dart';
import '../widgets/app_drawer.dart';

class ServerControlScreen extends StatefulWidget {
  final EC2Service? ec2Service;

  const ServerControlScreen({super.key, this.ec2Service});

  @override
  State<ServerControlScreen> createState() => _ServerControlScreenState();
}

class _ServerControlScreenState extends State<ServerControlScreen> {
  late final EC2Service _ec2Service;

  String _serverStatus = 'CHECKING...';
  bool _isLoading = false;
  bool _isOn = false;

  @override
  void initState() {
    super.initState();
    _ec2Service = widget.ec2Service ?? EC2Service();
    _fetchServerStatus();
  }

  Future<void> _fetchServerStatus() async {
    setState(() => _serverStatus = 'CHECKING...');
    final status = await _ec2Service.checkStatus();
    if (!mounted) return;
    final next = status.trim().toUpperCase();
    setState(() {
      _serverStatus = next;
      // EC2 state can be RUNNING/STOPPED/PENDING/STOPPING.
      // Consider PENDING as "on" so the switch doesn't flip back off during startup.
      _isOn = next == 'RUNNING' || next == 'PENDING';
    });
  }

  Future<void> _handleServerAction(String action) async {
    setState(() => _isLoading = true);

    final resultMessage = await _ec2Service.toggleServer(action);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultMessage)));

    await Future.delayed(const Duration(seconds: 3));
    await _fetchServerStatus();

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  bool get _canToggle {
    final status = _serverStatus.toUpperCase();
    final isTransitioning = status == 'STOPPING' || status == 'PENDING';
    return !_isLoading && !isTransitioning;
  }

  Future<void> _onToggle(bool next) async {
    if (!_canToggle) return;

    setState(() => _isOn = next);
    await _handleServerAction(next ? 'start' : 'stop');

    if (!mounted) return;
    setState(() {
      // Keep switch consistent with latest status after refresh.
      _isOn = _serverStatus == 'RUNNING' || _serverStatus == 'PENDING';
    });
  }

  Widget _cloudHeader(BuildContext context, {required bool isOn}) {
    final scheme = Theme.of(context).colorScheme;

    final Color top = isOn ? scheme.secondaryContainer : scheme.surfaceContainerHigh;
    final Color bottom = isOn ? scheme.tertiaryContainer : scheme.surfaceContainerLowest;
    final Color cloud = (isOn ? scheme.onSecondaryContainer : scheme.onSurface)
        .withValues(alpha: isOn ? 204 : 140);
    final Color accent = scheme.primary.withValues(alpha: isOn ? 64 : 38);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -40,
              top: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                ),
              ),
            ),

            // Clouds (replace the sun with clouds)
            Positioned(
              left: 18,
              top: 70,
              child: Icon(Icons.cloud_rounded, size: 84, color: cloud.withValues(alpha: 166)),
            ),
            Positioned(
              left: 62,
              top: 50,
              child: Icon(Icons.cloud_rounded, size: 108, color: cloud),
            ),
            Positioned(
              left: 140,
              top: 78,
              child: Icon(Icons.cloud_rounded, size: 76, color: cloud.withValues(alpha: 179)),
            ),
            Positioned(
              right: 20,
              top: 44,
              child: Icon(Icons.cloud_queue_rounded, size: 90, color: cloud.withValues(alpha: 191)),
            ),

            // Subtle dots for atmosphere
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DotsPainter(
                    color: (isOn ? scheme.onSecondaryContainer : scheme.onSurface)
                        .withValues(alpha: isOn ? 38 : 26),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Paris EC2 Web Server'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchServerStatus,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: KeyedSubtree(
                    key: ValueKey(_isOn),
                    child: _cloudHeader(context, isOn: _isOn),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    children: [
                      Text(
                        _isOn ? 'Cloud mode on' : 'Cloud mode off',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Toggle switch to change server state',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Status',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 10),
                          _StatusPill(status: _serverStatus),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _isLoading
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: CircularProgressIndicator(color: scheme.primary),
                            )
                          : Switch.adaptive(
                              value: _isOn,
                                onChanged: _canToggle ? _onToggle : null,
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'This sends Start/Stop commands to your AWS Lambda, which controls the EC2 instance running the web server.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final Color color;

  const _DotsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    // Fixed dot pattern (no randomness) to avoid visual jitter.
    const points = <Offset>[
      Offset(22, 22),
      Offset(44, 62),
      Offset(86, 38),
      Offset(112, 18),
      Offset(150, 44),
      Offset(190, 24),
      Offset(230, 58),
      Offset(260, 20),
      Offset(290, 42),
      Offset(320, 26),
      Offset(56, 108),
      Offset(104, 96),
      Offset(168, 112),
      Offset(216, 96),
      Offset(278, 112),
      Offset(310, 98),
    ];

    for (final p in points) {
      if (p.dx <= size.width && p.dy <= size.height) {
        canvas.drawCircle(p, 2.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter oldDelegate) => oldDelegate.color != color;
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  static Color _colorFor(String upperStatus) {
    if (upperStatus == 'RUNNING') return Colors.green;
    if (upperStatus == 'STOPPED') return Colors.red;
    if (upperStatus == 'PENDING') return Colors.orange;
    if (upperStatus == 'STOPPING') return Colors.orange;
    if (upperStatus == 'CHECKING...') return Colors.orange;
    if (upperStatus == 'OFFLINE') return Colors.orange;
    if (upperStatus.startsWith('ERROR') ||
        upperStatus.startsWith('HTTP') ||
        upperStatus.startsWith('NETWORK ERROR')) {
      return Colors.red;
    }
    return Colors.orange;
  }

  static String _labelFor(String upperStatus) {
    if (upperStatus == 'RUNNING') return 'RUNNING';
    if (upperStatus == 'STOPPED') return 'STOPPED';
    if (upperStatus == 'PENDING') return 'PENDING';
    if (upperStatus == 'STOPPING') return 'STOPPING';
    if (upperStatus == 'OFFLINE') return 'OFFLINE';
    if (upperStatus == 'CHECKING...') return 'CHECKING';
    if (upperStatus.startsWith('ERROR') ||
        upperStatus.startsWith('HTTP') ||
        upperStatus.startsWith('NETWORK ERROR')) {
      return 'ERROR';
    }
    return 'UNKNOWN';
  }

  @override
  Widget build(BuildContext context) {
    final upper = status.trim().toUpperCase();
    final c = _colorFor(upper);
    final label = _labelFor(upper);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      key: const Key('ec2StatusPill'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 56),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c, width: 0.9),
      ),
      child: Text(
        label,
        key: const Key('ec2StatusText'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: scheme.onSurface,
            ),
      ),
    );
  }
}
