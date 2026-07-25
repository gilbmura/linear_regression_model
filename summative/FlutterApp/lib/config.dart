/// Central configuration for the JAMB score prediction app.
///
/// The 8 input fields below match exactly the features of the trained model
/// (see summative/linear_regression/multivariate.ipynb). If the model changes,
/// update [apiBaseUrl] and [inputFields] here and nothing else.
library;

/// Base URL of the FastAPI service (no trailing slash).
/// Production API deployed on Render. For local development against a local
/// server from the Android emulator, use 'http://10.0.2.2:8000'.
const String apiBaseUrl = 'https://jamb-predictor-api.onrender.com';

/// Path of the prediction endpoint.
const String predictPath = '/predict';

/// Describes one input variable required by the model.
class InputFieldSpec {
  final String key; // JSON key sent to the API
  final String label; // label shown above the text field
  final String hint; // example value shown inside the field
  final String help; // explanation of the value/encoding
  final double min; // minimum accepted value (inclusive)
  final double max; // maximum accepted value (inclusive)
  final bool isInteger; // whether the value must be a whole number

  const InputFieldSpec({
    required this.key,
    required this.label,
    required this.hint,
    required this.help,
    required this.min,
    required this.max,
    this.isInteger = false,
  });
}

/// One entry per model input variable (11 features).
const List<InputFieldSpec> inputFields = [
  InputFieldSpec(
    key: 'study_hours_per_week',
    label: 'Study hours per week',
    hint: 'e.g. 20',
    help: 'Hours spent studying each week (0 – 60)',
    min: 0,
    max: 60,
  ),
  InputFieldSpec(
    key: 'attendance_rate',
    label: 'Attendance rate (%)',
    hint: 'e.g. 85',
    help: 'Class attendance percentage (0 – 100)',
    min: 0,
    max: 100,
  ),
  InputFieldSpec(
    key: 'teacher_quality',
    label: 'Teacher quality (1–5)',
    hint: 'e.g. 3',
    help: 'Rating of teaching quality: 1 = poor, 5 = excellent',
    min: 1,
    max: 5,
    isInteger: true,
  ),
  InputFieldSpec(
    key: 'distance_to_school',
    label: 'Distance to school (km)',
    hint: 'e.g. 5.5',
    help: 'One-way distance from home to school (0 – 50 km)',
    min: 0,
    max: 50,
  ),
  InputFieldSpec(
    key: 'parent_involvement',
    label: 'Parental involvement (0–2)',
    hint: 'e.g. 1',
    help: '0 = Low, 1 = Medium, 2 = High',
    min: 0,
    max: 2,
    isInteger: true,
  ),
  InputFieldSpec(
    key: 'it_knowledge',
    label: 'IT knowledge (0–2)',
    hint: 'e.g. 1',
    help: '0 = Low, 1 = Medium, 2 = High',
    min: 0,
    max: 2,
    isInteger: true,
  ),
  InputFieldSpec(
    key: 'extra_tutorials',
    label: 'Extra tutorials (0 or 1)',
    hint: 'e.g. 1',
    help: '0 = No extra tutorials, 1 = Attends extra tutorials',
    min: 0,
    max: 1,
    isInteger: true,
  ),
  InputFieldSpec(
    key: 'parent_education_level',
    label: 'Parent education level (0–3)',
    hint: 'e.g. 2',
    help: '0 = None, 1 = Primary, 2 = Secondary, 3 = Tertiary',
    min: 0,
    max: 3,
    isInteger: true,
  ),
  InputFieldSpec(
    key: 'assignments_completed',
    label: 'Assignments completed (0–5)',
    hint: 'e.g. 2',
    help: 'Number of assignments completed (0 – 5)',
    min: 0,
    max: 5,
    isInteger: true,
  ),
  InputFieldSpec(
    key: 'socioeconomic_status',
    label: 'Socioeconomic status (0–2)',
    hint: 'e.g. 1',
    help: '0 = Low, 1 = Medium, 2 = High',
    min: 0,
    max: 2,
    isInteger: true,
  ),
  InputFieldSpec(
    key: 'school_type',
    label: 'School type (0 or 1)',
    hint: 'e.g. 0',
    help: '0 = Public school, 1 = Private school',
    min: 0,
    max: 1,
    isInteger: true,
  ),
];

/// Name of the value being predicted, shown with the result.
const String predictionLabel = 'Predicted JAMB Score';
