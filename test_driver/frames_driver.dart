/// Runs integration_test/frames_test.dart in Chrome and saves what it
/// measured to build/frames.json.
library;

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
      responseDataCallback: (data) => writeResponseData(data, testOutputFilename: 'frames'),
    );
