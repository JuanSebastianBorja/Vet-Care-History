import 'package:flutter/material.dart';

class UserAvatarImage extends StatelessWidget {
  const UserAvatarImage({
    super.key,
    required this.avatarUrl,
    this.radius = 65,
    this.backgroundColor,
    this.iconColor,
    this.iconSize,
  });

  final String? avatarUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final bg = backgroundColor ?? Colors.grey.shade200;
    final icon = Icon(
      Icons.person_rounded,
      size: iconSize ?? radius,
      color: iconColor ?? Colors.grey.shade400,
    );

    if (url == null || url.isEmpty) {
      return CircleAvatar(radius: radius, backgroundColor: bg, child: icon);
    }

    print('🔗 URL DE LA FOTO DE PERFIL: $url');

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: Image.network(
          url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: radius * 2,
              height: radius * 2,
              child: Center(
                child: SizedBox(
                  width: radius * 0.5,
                  height: radius * 0.5,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: iconColor ?? Theme.of(context).primaryColor,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('🚨 Error cargando avatar de perfil: $error');
            return SizedBox(
              width: radius * 2,
              height: radius * 2,
              child: Center(child: icon),
            );
          },
        ),
      ),
    );
  }
}
