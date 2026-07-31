import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'flag_image.dart';

class Base64Image extends StatefulWidget {
  final String base64String;
  final double? width;
  final double? height;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final Widget? placeholder;

  const Base64Image({
    super.key,
    required this.base64String,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.high,
    this.placeholder,
  });

  @override
  State<Base64Image> createState() => _Base64ImageState();
}

class _Base64ImageState extends State<Base64Image> {
  Uint8List? _bytes;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant Base64Image oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64String != widget.base64String) {
      _decode();
    }
  }

  void _decode() {
    try {
      _bytes = base64Decode(widget.base64String);
      _hasError = false;
    } catch (e) {
      debugPrint('Error decoding base64 image: $e');
      _hasError = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || _bytes == null) {
      return widget.placeholder ??
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: Icon(
              Icons.broken_image,
              size: 16,
              color: Colors.grey.shade400,
            ),
          );
    }

    return FlagBytesImage(
      bytes: _bytes!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      filterQuality: widget.filterQuality,
      placeholder:
          widget.placeholder ??
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: Icon(
              Icons.error_outline,
              size: 16,
              color: Colors.red.shade200,
            ),
          ),
    );
  }
}
