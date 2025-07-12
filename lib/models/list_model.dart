import 'package:firebase_auth/firebase_auth.dart';

class ListModel {
  final String id;
  final String name;
  final String? groupId;

  ListModel({
    required this.id,
    required this.name,
    this.groupId,
  });

  ListModel copyWith({String? id, String? name, String? groupId}) {
    return ListModel(
      id: id ?? this.id,
      name: name ?? this.name,
      groupId: groupId ?? this.groupId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'groupId': groupId,
      'userId': FirebaseAuth.instance.currentUser?.uid, 
    };
  }

  factory ListModel.fromMap(Map<String, dynamic> map) {
    return ListModel(
      id: map['id'],
      name: map['name'],
      groupId: map['groupId'],
    );
  }
}
