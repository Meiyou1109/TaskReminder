import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';
import '../models/list_model.dart';
import '../models/group.dart';

class FirebaseTaskService {
  final _db = FirebaseFirestore.instance;

  // TASK

  // Tạo task trên Firestore
  Future<void> syncAddTask(Task task) async {
    await _db.collection('tasks').doc(task.id).set(task.toMap());
  }

  // Cập nhật task
  Future<void> syncUpdateTask(Task task) async {
    await _db.collection('tasks').doc(task.id).update(task.toMap());
  }

  // Xoá task
  Future<void> syncDeleteTask(Task task) async {
    await _db.collection('tasks').doc(task.id).delete();
  }

  // Lấy all task của user
  Future<List<Task>> getTasks(String userId) async {
    final query = await _db
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .get();

    return query.docs.map((doc) => Task.fromMap(doc.data())).toList();
  }

  // LIST 

  Future<void> saveList(ListModel list) async {
    await _db.collection('lists').doc(list.id).set(list.toMap());
  }

  Future<List<ListModel>> loadLists() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];
    
    final snapshot = await _db
        .collection('lists')
        .where('userId', isEqualTo: userId)
        .get();

    return snapshot.docs.map((doc) => ListModel.fromMap(doc.data())).toList();
  }

  Future<void> deleteList(String listId) async {
    await _db.collection('lists').doc(listId).delete();
  }

  // GROUP

  Future<void> saveGroup(Group group) async {
    await _db.collection('groups').doc(group.id).set(group.toMap());
  }

  Future<List<Group>> loadGroups() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    final snapshot = await _db
        .collection('groups')
        .where('userId', isEqualTo: userId)
        .get();

    return snapshot.docs.map((doc) => Group.fromMap(doc.data())).toList();
  }

  Future<void> deleteGroup(String groupId) async {
    await _db.collection('groups').doc(groupId).delete();
  }
}
