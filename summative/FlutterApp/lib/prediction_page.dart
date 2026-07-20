import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;

  bool _loading = false;
  String? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in inputFields) field.key: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validate(InputFieldSpec spec, String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return '${spec.label} is required';
    }
    final value = double.tryParse(raw.trim());
    if (value == null) {
      return 'Enter a valid number';
    }
    if (spec.isInteger && value != value.roundToDouble()) {
      return '${spec.label} must be a whole number';
    }
    if (value < spec.min || value > spec.max) {
      return 'Must be between ${_fmt(spec.min)} and ${_fmt(spec.max)}';
    }
    return null;
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _predict() async {
    setState(() {
      _result = null;
      _error = null;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() => _error = 'Please fix the highlighted fields above.');
      return;
    }

    final payload = <String, dynamic>{};
    for (final field in inputFields) {
      final value = double.parse(_controllers[field.key]!.text.trim());
      payload[field.key] = field.isInteger ? value.toInt() : value;
    }

    setState(() => _loading = true);
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl$predictPath'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        final prediction = body['prediction'];
        setState(() => _result = _formatPrediction(prediction));
      } else {
        setState(() => _error = _extractApiError(body, response.statusCode));
      }
    } on TimeoutException {
      setState(() => _error = 'The request timed out. Please try again.');
    } catch (_) {
      setState(() =>
          _error = 'Could not reach the prediction service. '
              'Check your connection and try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatPrediction(dynamic prediction) {
    if (prediction is num) {
      return prediction.toStringAsFixed(2);
    }
    return prediction.toString();
  }

  /// Turns FastAPI/Pydantic error bodies into a readable message.
  String _extractApiError(Map<String, dynamic> body, int statusCode) {
    final detail = body['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      final messages = detail
          .whereType<Map<String, dynamic>>()
          .map((e) {
            final loc = (e['loc'] as List?)?.last ?? 'input';
            return '$loc: ${e['msg']}';
          })
          .join('\n');
      if (messages.isNotEmpty) return messages;
    }
    return 'Prediction failed (error $statusCode).';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('JAMB Score Predictor'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Enter the student\'s details below and press Predict '
                      'to estimate their JAMB UTME score (0 – 400).',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    for (final field in inputFields) ...[
                      TextFormField(
                        controller: _controllers[field.key],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^-?\d*\.?\d*$'),
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: field.label,
                          hintText: field.hint,
                          helperText: field.help,
                          helperMaxLines: 2,
                        ),
                        validator: (value) => _validate(field, value),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 4),
                    FilledButton(
                      onPressed: _loading ? null : _predict,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Text('Predict'),
                    ),
                    const SizedBox(height: 24),
                    _ResultCard(result: _result, error: _error),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Display area for the prediction result or an error message.
class _ResultCard extends StatelessWidget {
  final String? result;
  final String? error;

  const _ResultCard({required this.result, required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (result == null && error == null) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text('The prediction result will appear here.'),
          ),
        ),
      );
    }

    final isError = error != null;
    return Card(
      elevation: 0,
      color: isError
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 32,
              color: isError
                  ? theme.colorScheme.onErrorContainer
                  : theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(height: 8),
            Text(
              isError ? 'Error' : predictionLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isError
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isError ? error! : result!,
              textAlign: TextAlign.center,
              style: isError
                  ? theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    )
                  : theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
