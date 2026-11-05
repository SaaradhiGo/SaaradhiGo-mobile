/// What to call a vehicle class in front of a rider.
///
/// THE BACKEND IDENTIFIER NEVER CHANGES. Pricing, dispatch and the trip
/// record key on `auto`, `hatchback`, `sedan`, `suv`; this file is display
/// only, and mirrors the website's `lib/vehicles.ts` so both products call a
/// class the same thing (`hatchback` is "Mini" to riders).
///
/// The app used to ask for `bike`, `car`, `car_xl` and `car_premium`, which
/// no zone prices, so three of its five rows showed "₹…" and could never be
/// booked (PRODUCT_AUDIT §2, Choose ride). The list now comes from
/// `/pricing/vehicle-types/` for the pickup point.
library;

import 'package:flutter/material.dart';

/// Asked for when `/pricing/vehicle-types/` cannot be reached. Only classes
/// that come back with a fare are shown, so an unpriced one never appears.
const List<String> kFallbackVehicleTypes = ['auto', 'hatchback', 'sedan', 'suv'];

/// The public name for a backend class.
String vehicleClassName(String? type) {
  final key = (type ?? '').trim().toLowerCase();
  switch (key) {
    case 'auto':
      return 'Auto';
    case 'hatchback':
    case 'mini':
      return 'Mini';
    case 'sedan':
      return 'Sedan';
    case 'suv':
      return 'SUV';
    case 'bike':
      return 'Bike';
  }
  if (key.isEmpty) return 'Ride';
  // A class added on the server renders readably instead of disappearing.
  final words = key.split(RegExp(r'[_\s]+')).where((w) => w.isNotEmpty);
  return words
      .map((w) => w.length <= 2 ? w.toUpperCase() : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

IconData vehicleClassIcon(String? type) {
  switch ((type ?? '').trim().toLowerCase()) {
    case 'auto':
      return Icons.electric_rickshaw;
    case 'bike':
      return Icons.two_wheeler;
    case 'suv':
      return Icons.airport_shuttle;
    default:
      return Icons.directions_car;
  }
}

/// Average city speed for the "Drop in N min" line, km/h.
int vehicleClassSpeedKmh(String? type) {
  switch ((type ?? '').trim().toLowerCase()) {
    case 'bike':
      return 40;
    case 'auto':
      return 30;
    default:
      return 35;
  }
}

/// The gold line glyph for a class (assets/vehicles); unknown classes get the sedan.
String vehicleClassAsset(String? type) {
  switch ((type ?? '').trim().toLowerCase()) {
    case 'bike':
      return 'assets/vehicles/bike.svg';
    case 'auto':
      return 'assets/vehicles/auto.svg';
    case 'hatchback':
    case 'mini':
      return 'assets/vehicles/hatchback.svg';
    case 'suv':
      return 'assets/vehicles/suv.svg';
    case 'black':
    case 'premium':
    case 'car_premium':
      return 'assets/vehicles/premium.svg';
  }
  return 'assets/vehicles/sedan.svg';
}

/// Seats a class carries, shown when the fare API does not say.
int? vehicleClassSeats(String? type) {
  switch ((type ?? '').trim().toLowerCase()) {
    case 'bike':
      return 1;
    case 'auto':
      return 3;
    case 'hatchback':
    case 'mini':
    case 'sedan':
    case 'black':
    case 'premium':
    case 'car_premium':
      return 4;
    case 'suv':
      return 6;
  }
  return null;
}
