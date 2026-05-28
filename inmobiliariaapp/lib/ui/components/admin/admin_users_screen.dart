import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/models/user.dart';
import 'package:inmobiliariaapp/services/user_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final UserService _userService = UserService();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      // 1. Cambiado de QuerySnapshot a List<UserModel>
      stream: _userService.watchAllUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // 2. Cambiado snapshot.data!.docs por snapshot.data!
        final List<UserModel> users = snapshot.data!;
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(user.name),
              subtitle: Text("${user.email} - Rol: ${user.role}"),
              trailing: const Icon(Icons.chevron_right),
            );
          },
        );
      },
    );
  }
}
