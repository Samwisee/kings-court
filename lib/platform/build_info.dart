/// Facts about this build, set by CI with --dart-define.
library;

/// Which build this is (the commit), or `dev` for a local build.
const buildVersion = String.fromEnvironment('BUILD', defaultValue: 'dev');
