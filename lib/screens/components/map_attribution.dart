import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Map attribution required by the OpenStreetMap and CARTO licence terms.
/// Drop this widget into a FlutterMap's `children` to satisfy both.
///
/// Both services explicitly require visible attribution in any product
/// using their tiles. Without this we are in technical violation of the
/// tile licences and our tile access can be revoked.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return const RichAttributionWidget(
      alignment: AttributionAlignment.bottomRight,
      attributions: [
        TextSourceAttribution(
          'OpenStreetMap contributors',
          prependCopyright: true,
        ),
        TextSourceAttribution(
          'CARTO',
          prependCopyright: false,
        ),
      ],
    );
  }
}
