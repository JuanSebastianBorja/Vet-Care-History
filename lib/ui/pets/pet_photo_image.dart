import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/pet_model.dart';

class PetPhotoImage extends StatelessWidget {
  const PetPhotoImage({
    super.key,
    required this.pet,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.loadingBuilder,
  });

  final PetModel pet;
  final BoxFit fit;
  final Widget Function()? placeholder;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;

  @override
  Widget build(BuildContext context) {
    final localPath = pet.localPhotoPath;
    if (localPath != null && localPath.isNotEmpty) {
      return Image.file(
        File(localPath),
        fit: fit,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    final url = pet.photoUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: fit,
        errorBuilder: (_, __, ___) => _fallback(),
        loadingBuilder: loadingBuilder,
      );
    }

    return _fallback();
  }

  Widget _fallback() => placeholder?.call() ?? const SizedBox.shrink();
}
