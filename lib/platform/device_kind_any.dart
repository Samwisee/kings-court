/// The kind of device off the web: the platform's name.
library;

import 'package:flutter/foundation.dart';

String deviceKind() => defaultTargetPlatform.name;
