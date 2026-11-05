/// App version, set at build time (`--dart-define=BUILD_NAME=…`, see release script).
const appVersion = String.fromEnvironment('BUILD_NAME', defaultValue: '1.0.0');
