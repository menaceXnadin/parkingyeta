import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileAvatar extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;

  const ProfileAvatar({super.key, this.size = 40, this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: size / 2 - 2,
              backgroundColor: Colors.grey[300],
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? Icon(
                      Icons.person,
                      size: size * 0.6,
                      color: Colors.grey[600],
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}
