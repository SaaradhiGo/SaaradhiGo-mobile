/// Bodies of GET /api/v1/app-config/?country=XX&app=rider, in the exact shape
/// the backend returns (servers/platform_ops/app_config.py::build, wrapped by
/// success_response). Copied from that serializer, not invented by the app.
///
/// QA today: India, no notices, no minimum version set.
library;

import 'dart:convert';

Map<String, dynamic> _doc(Map<String, dynamic> data) => {
  'status': 'success',
  'data': {
    ...data,
    'flags': <String, dynamic>{},
    'generated_at': '2026-11-01T09:00:00+00:00',
  },
  'meta': {'timestamp': '2026-11-01T09:00:00+05:30'},
};

const _anyVersions = {
  'rider': {
    'android': {
      'minimum_version': '0.0.0',
      'latest_version': '0.0.0',
      'store_url': '',
      'message': '',
    },
    'ios': {
      'minimum_version': '0.0.0',
      'latest_version': '0.0.0',
      'store_url': '',
      'message': '',
    },
  },
};

Map<String, dynamic> _hyderabad() => {
  'code': 'HYD',
  'name': 'Hyderabad',
  'state': {'code': 'TG', 'name': 'Telangana'},
  'service_area': {
    'center': {'lat': 17.385, 'lng': 78.4867},
    'bounds': {
      'south': 17.2,
      'west': 78.23,
      'north': 17.54,
      'east': 78.55,
    },
  },
};

/// India as QA serves it: one live city here is enough (QA has more; the
/// tests that care add them).
Map<String, dynamic> indiaBody({
  List<Map<String, dynamic>>? cities,
  List<Map<String, dynamic>> notices = const [],
}) => _doc({
  'country': {
    'code': 'IN',
    'name': 'India',
    'calling_code': '91',
    'phone': {
      'calling_code': '91',
      'national_number_lengths': [10],
    },
    'currency': {
      'code': 'INR',
      'symbol': '₹',
      'symbol_position': 'prefix',
      'minor_units': 2,
    },
    'distance_unit': 'km',
    'tax': {'mode': 'inclusive', 'label': 'GST'},
    'emergency': {
      'numbers': [
        {'kind': 'unified', 'number': '112'},
      ],
      'label': 'Emergency services',
    },
  },
  'status': 'live',
  'cities': cities ?? [_hyderabad()],
  'languages': ['en', 'hi', 'te'],
  'app_versions': _anyVersions,
  'notices': notices,
});

Map<String, dynamic> usBody({
  List<Map<String, dynamic>> notices = const [],
}) => _doc({
  'country': {
    'code': 'US',
    'name': 'United States',
    'calling_code': '1',
    'phone': {
      'calling_code': '1',
      'national_number_lengths': [10],
    },
    'currency': {
      'code': 'USD',
      'symbol': r'$',
      'symbol_position': 'prefix',
      'minor_units': 2,
    },
    'distance_unit': 'mi',
    'tax': {'mode': 'additive', 'label': 'Sales tax'},
    'emergency': {
      'numbers': [
        {'kind': 'unified', 'number': '911'},
      ],
      'label': 'Emergency services',
    },
  },
  'status': 'live',
  'cities': [
    {
      'code': 'AUS',
      'name': 'Austin',
      'state': {'code': 'TX', 'name': 'Texas'},
      'service_area': {
        'center': {'lat': 30.2672, 'lng': -97.7431},
        'bounds': {
          'south': 30.1,
          'west': -97.95,
          'north': 30.5,
          'east': -97.55,
        },
      },
    },
  ],
  'languages': ['en'],
  'app_versions': _anyVersions,
  'notices': notices,
});

/// A notice as notices.public_dict returns it.
Map<String, dynamic> noticeJson({
  int id = 7,
  String message = 'Scheduled maintenance tonight 1-2 AM. Booking may be slow.',
  String severity = 'warning',
}) => {
  'id': id,
  'message': message,
  'severity': severity,
  'audience': 'rider',
  'scope': null,
  'starts_at': '2026-11-01T00:00:00+00:00',
  'ends_at': '2026-11-02T00:00:00+00:00',
};

/// The 426 body: base.utils.error_response plus error.update
/// (versions.update_required_response).
String updateRequiredBody({
  String message = 'Please update the app to continue.',
  String storeUrl =
      'https://play.google.com/store/apps/details?id=com.saaradhigo.rider',
}) => jsonEncode({
  'status': 'error',
  'error': {
    'code': 'APP_UPDATE_REQUIRED',
    'message': message,
    'details': {
      'field': 'app_version',
      'issue': 'This app version is below the minimum supported version',
    },
    'update': {
      'minimum_version': '2.0.0',
      'latest_version': '2.1.0',
      'store_url': storeUrl,
    },
  },
});

/// A booking refusal as error_response builds it (REST estimate-fare, 400).
String bookingRefusalBody(String code, String message) => jsonEncode({
  'status': 'error',
  'error': {
    'code': code,
    'message': message,
    'details': {
      'field': 'pickup / destination',
      'issue': 'Coordinates fall outside every active SaaradhiGo service zone',
    },
  },
});
