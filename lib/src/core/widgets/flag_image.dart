import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;

const int _maxSvgBytes = 1024 * 1024;

bool isSvgBytes(Uint8List bytes) {
  if (bytes.isEmpty) return false;
  final sample = utf8
      .decode(bytes.take(1024).toList(growable: false), allowMalformed: true)
      .replaceFirst('\uFEFF', '')
      .trimLeft();
  return sample.startsWith('<svg') ||
      (sample.startsWith('<?xml') && sample.contains('<svg'));
}

String flagUploadFilename(Uint8List bytes) =>
    isSvgBytes(bytes) ? 'flag.svg' : 'flag.png';

/// Conserva un SVG vectorial byte a byte. Las imágenes ráster se normalizan a
/// PNG y a un máximo de 512 px para mantener el comportamiento anterior.
Uint8List normalizeFlagImageBytes(Uint8List bytes) {
  if (isSvgBytes(bytes)) {
    if (bytes.length > _maxSvgBytes) {
      throw const FormatException('El SVG supera el límite de 1 MB.');
    }
    return bytes;
  }

  final image = img.decodeImage(bytes);
  if (image == null) {
    throw const FormatException('Formato de imagen no compatible.');
  }
  final resized = image.width > 512 || image.height > 512
      ? img.copyResize(
          image,
          width: image.width > image.height ? 512 : null,
          height: image.height >= image.width ? 512 : null,
          maintainAspect: true,
        )
      : image;
  return Uint8List.fromList(img.encodePng(resized));
}

class FlagBytesImage extends StatelessWidget {
  const FlagBytesImage({
    super.key,
    required this.bytes,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.high,
    this.placeholder,
  });

  final Uint8List bytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    if (isSvgBytes(bytes)) {
      return SvgPicture.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        placeholderBuilder: placeholder == null ? null : (_) => placeholder!,
        errorBuilder: placeholder == null ? null : (_, _, _) => placeholder!,
      );
    }

    return Image.memory(
      bytes,
      width: width,
      height: height,
      fit: fit,
      filterQuality: filterQuality,
      gaplessPlayback: true,
      errorBuilder: placeholder == null ? null : (_, _, _) => placeholder!,
    );
  }
}
