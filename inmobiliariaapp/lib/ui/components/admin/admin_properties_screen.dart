import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminPropertiesScreen extends StatelessWidget {
  const AdminPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('properties').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final props = snapshot.data!.docs;
        return ListView.builder(
          itemCount: props.length,
          itemBuilder: (context, index) {
            final prop = props[index].data() as Map<String, dynamic>;
            final String status = prop['status'] ?? 'pending';
            
            return Card(
              child: ListTile(
                title: Text(prop['address']),
                subtitle: Text("Estado: ${status.toUpperCase()}"),
                trailing: Switch(
                  value: status == 'active',
                  onChanged: (val) {
                    props[index].reference.update({'status': val ? 'active' : 'pending'});
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}