import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hau_pokemon/screens/server_control_screen.dart';
import 'package:hau_pokemon/services/ec2_service.dart';
import 'package:hau_pokemon/theme/pokedex_theme.dart';

class _FakeEC2Service extends EC2Service {
  final String status;

  _FakeEC2Service(this.status);

  @override
  Future<String> checkStatus() async => status;

  @override
  Future<String> toggleServer(String action) async => 'ok';
}

BoxDecoration _pillDecoration(WidgetTester tester) {
  final container = tester.widget<Container>(find.byKey(const Key('ec2StatusPill')));
  return container.decoration! as BoxDecoration;
}

void main() {
  Future<void> pumpWithStatus(WidgetTester tester, String status) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PokedexTheme.dark(),
        home: ServerControlScreen(ec2Service: _FakeEC2Service(status)),
      ),
    );

    // Let initState async status load complete.
    await tester.pumpAndSettle();
  }

  testWidgets('RUNNING shows green status pill', (tester) async {
    await pumpWithStatus(tester, 'running');
    final decoration = _pillDecoration(tester);
    final border = decoration.border! as Border;
    expect(border.top.color, Colors.green);
    expect(find.byKey(const Key('ec2StatusText')), findsOneWidget);
  });

  testWidgets('STOPPED shows red status pill', (tester) async {
    await pumpWithStatus(tester, 'stopped');
    final decoration = _pillDecoration(tester);
    final border = decoration.border! as Border;
    expect(border.top.color, Colors.red);
    expect(find.byKey(const Key('ec2StatusText')), findsOneWidget);
  });

  testWidgets('OFFLINE shows orange status pill', (tester) async {
    await pumpWithStatus(tester, 'offline');
    final decoration = _pillDecoration(tester);
    final border = decoration.border! as Border;
    expect(border.top.color, Colors.orange);
    expect(find.byKey(const Key('ec2StatusText')), findsOneWidget);
  });
}
