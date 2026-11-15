import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/config/app_theme.dart';
import '../core/utils/text_utils.dart';
import '../data/models/radio_station.dart';

/// Memory-efficient logo: decoded at display size (memCacheWidth), cached on
/// disk, and falls back to a coloured monogram when no logo is available.
class StationLogo extends StatelessWidget {
  const StationLogo({super.key, required this.station, this.size = 56, this.radius = 12});

  final RadioStation station;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final px = (size * dpr).round().clamp(32, 512);
    final fallback = _Monogram(station: station, size: size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: station.logo == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: station.logo!,
                memCacheWidth: px,
                maxWidthDiskCache: 512,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.station, required this.size});
  final RadioStation station;
  final double size;

  static const _palette = [
    AppColors.navy,
    AppColors.turquoiseDark,
    Color(0xFF1D4E89),
    Color(0xFF117A8B),
    Color(0xFF283C63),
    Color(0xFF0F6E6E),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[station.id.hashCode.abs() % _palette.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, AppColors.turquoise, 0.45)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          TextUtils.initials(station.name),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.34),
        ),
      ),
    );
  }
}
