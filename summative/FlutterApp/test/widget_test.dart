import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prediction_app/config.dart';
import 'package:prediction_app/main.dart';

void main() {
  testWidgets('Prediction page renders all fields, button and display area',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PredictionApp());

    // One text field per model input variable.
    expect(find.byType(TextFormField), findsNWidgets(inputFields.length));

    // The Predict button.
    expect(find.text('Predict'), findsOneWidget);

    // The result display area placeholder.
    expect(find.text('The prediction result will appear here.'), findsOneWidget);
  });
}
