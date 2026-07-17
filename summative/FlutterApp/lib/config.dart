/// Central configuration for the prediction app.
///
/// When the dataset and model are finalized, update [apiBaseUrl] with the
/// deployed Render URL and edit [inputFields] so there is exactly one entry
/// per variable the model expects. Nothing else in the app needs to change.
library;

/// Base URL of the FastAPI service (no trailing slash).
/// Use the deployed Render URL in production, e.g. https://my-api.onrender.com
const String apiBaseUrl = 'http://10.0.2.2:8000';

/// Path of the prediction endpoint.
const String predictPath = '/predict';

/// Describes one input variable required by the model.
class InputFieldSpec {
  final String key; // JSON key sent to the API
  final String label; // label shown above the text field
  final String hint; // example value shown inside the field
  final double min; // minimum accepted value (inclusive)
  final double max; // maximum accepted value (inclusive)
  final bool isInteger; // whether the value must be a whole number

  const InputFieldSpec({
    required this.key,
    required this.label,
    required this.hint,
    required this.min,
    required this.max,
    this.isInteger = false,
  });
}

/// One entry per model input variable.
/// PLACEHOLDER values - replace with the real dataset features once the
/// regression model is finalized.
const List<InputFieldSpec> inputFields = [
  InputFieldSpec(
    key: 'feature_1',
    label: 'Feature 1',
    hint: 'e.g. 25',
    min: 0,
    max: 100,
  ),
  InputFieldSpec(
    key: 'feature_2',
    label: 'Feature 2',
    hint: 'e.g. 3.5',
    min: 0,
    max: 10,
  ),
  InputFieldSpec(
    key: 'feature_3',
    label: 'Feature 3',
    hint: 'e.g. 1200',
    min: 0,
    max: 10000,
  ),
  InputFieldSpec(
    key: 'feature_4',
    label: 'Feature 4',
    hint: 'e.g. 7',
    min: 1,
    max: 31,
    isInteger: true,
  ),
];

/// Name of the value being predicted, shown with the result.
const String predictionLabel = 'Predicted value';
