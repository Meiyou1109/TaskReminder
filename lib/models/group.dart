import 'package:firebase_auth/firebase_auth.dart';


class Group {
  final String id;
  final String name;

  Group({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'userId': FirebaseAuth.instance.currentUser?.uid,
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'],
      name: map['name'],
    );
  }
}
