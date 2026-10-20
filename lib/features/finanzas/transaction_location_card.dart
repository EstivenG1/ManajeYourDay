import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';

class TransactionLocationCard extends StatefulWidget {
  const TransactionLocationCard({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  State<TransactionLocationCard> createState() =>
      _TransactionLocationCardState();
}

class _TransactionLocationCardState extends State<TransactionLocationCard> {
  String? _address;
  String? _placeName;
  bool _loadingAddress = true;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    try {
      await setLocaleIdentifier('es_CO');
      final placemarks = await placemarkFromCoordinates(
        widget.latitude,
        widget.longitude,
      );
      if (!mounted || placemarks.isEmpty) return;
      final place = placemarks.first;
      final name = place.name?.trim();
      final street = [place.street, place.subLocality]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toSet()
          .join(', ');
      final locality = [place.locality, place.administrativeArea]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toSet()
          .join(', ');
      final address = [street, locality, place.country]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toSet()
          .join(' · ');
      setState(() {
        _placeName = name != null && name.isNotEmpty && name != street
            ? name
            : null;
        _address = address.isEmpty ? null : address;
        _loadingAddress = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(widget.latitude, widget.longitude);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 190,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 16,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.myd',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 46,
                      height: 46,
                      child: Icon(
                        Icons.location_on,
                        color: AppColors.red,
                        size: 42,
                        shadows: [Shadow(color: Colors.white, blurRadius: 8)],
                      ),
                    ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_outlined, color: AppColors.goldDeep),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _loadingAddress
                            ? 'Buscando dirección…'
                            : _placeName ??
                                  _address ??
                                  'Dirección no disponible',
                        style: AppTypography.itemTitle,
                      ),
                      if (_address != null && _placeName != null) ...[
                        const SizedBox(height: 3),
                        Text(_address!, style: AppTypography.secondary),
                      ],
                      const SizedBox(height: 3),
                      Text(
                        '${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}',
                        style: AppTypography.secondary.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
