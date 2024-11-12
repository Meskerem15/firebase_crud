import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(TaskManagerApp());
}

class TaskManagerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthenticationWrapper(),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          return const TaskListScreen(); // If user is signed in, show TaskListScreen
        }
        return SignInScreen(); // If user is not signed in, show SignInScreen
      },
    );
  }
}

class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = false;

  Future<void> _signInWithEmailPassword(BuildContext context) async {
    setState(() {
      isLoading = true;
    });
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showErrorDialog(context, 'Error signing in: ${e.message}');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _signUpWithEmailPassword(BuildContext context) async {
    setState(() {
      isLoading = true;
    });
    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showErrorDialog(context, 'Error signing up: ${e.message}');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton(
                        onPressed: () => _signInWithEmailPassword(context),
                        child: const Text('Sign In'),
                      ),
                      ElevatedButton(
                        onPressed: () => _signUpWithEmailPassword(context),
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}


class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _subTaskNameController = TextEditingController();
  final TextEditingController _subTaskTimeController = TextEditingController();
  final TextEditingController _subTaskDayController = TextEditingController();

  CollectionReference tasksCollection = FirebaseFirestore.instance.collection('tasks');

  Future<void> _addTask() async {
    if (_taskController.text.isNotEmpty) {
      await tasksCollection.add({
        'name': _taskController.text,
        'isCompleted': false,
        'userId': _auth.currentUser?.uid,
        'subTasks': [],
      });
      _taskController.clear(); // Clears the input field after adding the task
    }
  }

  Future<void> _addSubTask(String taskId) async {
    if (_subTaskNameController.text.isNotEmpty &&
        _subTaskTimeController.text.isNotEmpty &&
        _subTaskDayController.text.isNotEmpty) {
      await tasksCollection.doc(taskId).update({
        'subTasks': FieldValue.arrayUnion([
          {
            'name': _subTaskNameController.text,
            'time': _subTaskTimeController.text,
            'day': _subTaskDayController.text,
          }
        ]),
      });
      _subTaskNameController.clear();
      _subTaskTimeController.clear();
      _subTaskDayController.clear();
    }
  }

  Future<void> _toggleTaskCompletion(String taskId, bool currentStatus) async {
    await tasksCollection.doc(taskId).update({
      'isCompleted': !currentStatus,
    });
    setState(() {}); // Force UI update after the task is updated
  }

  Future<void> _deleteTask(String taskId) async {
    await tasksCollection.doc(taskId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => TaskManagerApp()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: const InputDecoration(
                      labelText: 'Enter task name',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addTask,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: tasksCollection
                  .where('userId', isEqualTo: _auth.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No tasks available.'));
                }

                final tasks = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    var task = tasks[index];
                    var taskId = task.id;
                    var taskName = task['name'];
                    var isCompleted = task['isCompleted'];

                    var data = task.data() as Map<String, dynamic>?;
                    var subTasks = data != null && data.containsKey('subTasks') 
                        ? List.from(data['subTasks']) 
                        : [];

                    // Group sub-tasks by day
                    Map<String, List<Map<String, dynamic>>> subTasksByDay = {};
                    for (var subTask in subTasks) {
                      String day = subTask['day'] ?? "Unspecified Day";
                      if (subTasksByDay.containsKey(day)) {
                        subTasksByDay[day]!.add(subTask);
                      } else {
                        subTasksByDay[day] = [subTask];
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      child: ListTile(
                        title: Text(
                          taskName,
                          style: TextStyle(
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        leading: Checkbox(
                          value: isCompleted,
                          onChanged: (value) {
                            _toggleTaskCompletion(taskId, isCompleted);
                          },
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteTask(taskId),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Display sub-tasks grouped by day
                            if (subTasksByDay.isNotEmpty)
                              ...subTasksByDay.entries.map((entry) {
                                String day = entry.key;
                                List<Map<String, dynamic>> subTaskList = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        day,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      ...subTaskList.map((subTask) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Text(
                                            '- ${subTask['name']} (${subTask['time']})',
                                            style: const TextStyle(fontStyle: FontStyle.italic),
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                );
                              }).toList(),
                            // Input fields for adding new sub-tasks (will always be visible)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _subTaskNameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Sub-task name',
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.0),
                                  Expanded(
                                    child: TextField(
                                      controller: _subTaskTimeController,
                                      decoration: const InputDecoration(
                                        labelText: 'Time',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () => _addSubTask(taskId),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


