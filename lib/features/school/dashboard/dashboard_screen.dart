import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:udaan_campus/models/user_role.dart';
import 'package:udaan_campus/services/auth_provider.dart';
import 'package:udaan_campus/features/school/paper/paper_screen.dart';
import 'package:udaan_campus/widgets/udaan_logo.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    switch (user.role) {
      case UserRole.superManager:
        return const ManagerDashboard();
      case UserRole.manager:
        return const ManagerDashboard();
      case UserRole.teacher:
        return const TeacherDashboard();
      case UserRole.parent:
        return const ParentDashboard();
      case UserRole.student:
      default:
        return const StudentDashboard();
    }
  }
}

class DashboardShell extends StatelessWidget {
  const DashboardShell({
    super.key,
    required this.title,
    required this.description,
    required this.children,
    required this.accentColor,
    this.quickStats = const [],
  });

  final String title;
  final String description;
  final List<Widget> children;
  final Color accentColor;
  final List<String> quickStats;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final lightAccent = accentColor.withAlpha((0.18 * 255).round());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Udaan Edu ERP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: auth.signOut,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withAlpha((0.22 * 255).round()),
                    accentColor.withAlpha((0.10 * 255).round()),
                    Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: accentColor.withAlpha((0.28 * 255).round()), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withAlpha((0.10 * 255).round()),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const UdaanLogo(size: 42, light: true),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Udaan Edu ERP',
                              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(description, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black87)),
                  if (quickStats.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: quickStats
                          .map((stat) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha((0.82 * 255).round()),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: lightAccent, width: 1),
                                ),
                                child: Text(
                                  stat,
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: accentColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (user != null)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withAlpha((0.10 * 255).round()),
                      Colors.white,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: lightAccent, width: 1),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: accentColor,
                    child: Text(
                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : user.role[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(user.displayName.isNotEmpty ? user.displayName : user.email, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Role: ${user.role}'),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 3,
                children: children,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: Text(
                'Udaan Academy • Developed by Udaan Academy',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardActionCard extends StatelessWidget {
  const DashboardActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withAlpha((0.16 * 255).round()), width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withAlpha((0.12 * 255).round()),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class ManagerDashboard extends StatelessWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      title: 'Manager Panel',
      description: 'Manage school operations, users, and academic resources.',
      accentColor: const Color(0xFF2563EB),
      quickStats: const ['Operations', 'Academics', 'Insights'],
      children: [
        DashboardActionCard(
          icon: Icons.people,
          title: 'User Management',
          subtitle: 'Add or update teachers, parents and students.',
          accentColor: const Color(0xFF2563EB),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
        ),
        DashboardActionCard(
          icon: Icons.class_,
          title: 'Classes & Sections',
          subtitle: 'Create classes, assign teachers and review schedules.',
          accentColor: const Color(0xFF1D4ED8),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClassManagementScreen())),
        ),
        DashboardActionCard(
          icon: Icons.event_available,
          title: 'Attendance',
          subtitle: 'Monitor attendance across the school.',
          accentColor: const Color(0xFF0EA5E9),
          onTap: () => Navigator.pushNamed(context, '/attendance_home'),
        ),
        DashboardActionCard(
          icon: Icons.assignment,
          title: 'Homework',
          subtitle: 'Track homework assignments and deadlines.',
          accentColor: const Color(0xFF3B82F6),
          onTap: () => Navigator.pushNamed(context, '/homework'),
        ),
        DashboardActionCard(
          icon: Icons.fact_check,
          title: 'Result',
          subtitle: 'Enter unit, half yearly and yearly exam marks for each class.',
          accentColor: const Color(0xFF2563EB),
          onTap: () => Navigator.pushNamed(context, '/result'),
        ),
        DashboardActionCard(
          icon: Icons.campaign,
          title: 'Notice Board',
          subtitle: 'View school-wide notices and recent updates.',
          accentColor: const Color(0xFF0F766E),
          onTap: () => Navigator.pushNamed(context, '/notice_board'),
        ),
        DashboardActionCard(
          icon: Icons.school_outlined,
          title: 'Learning',
          subtitle: 'Create and share YouTube or MP4 learning courses for all users.',
          accentColor: const Color(0xFF7C3AED),
          onTap: () => Navigator.pushNamed(context, '/learning'),
        ),
        DashboardActionCard(
          icon: Icons.analytics,
          title: 'Reports',
          subtitle: 'Review performance, logs, and audit activities.',
          accentColor: const Color(0xFF10B981),
          onTap: () => Navigator.pushNamed(context, '/exam_results'),
        ),
        DashboardActionCard(
          icon: Icons.description,
          title: 'Paper',
          subtitle: 'Generate objective, short and long answer papers with PDF sharing.',
          accentColor: const Color(0xFFDC2626),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaperScreen())),
        ),
      ],
    );
  }
}

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    bool canAccess(String permission) {
      final permissions = user?.accessPermissions;
      return permissions == null || permissions.isEmpty || permissions.contains(permission);
    }

    return DashboardShell(
      title: 'Teacher Panel',
      description: 'Manage classes, attendance, homework, and student progress.',
      accentColor: const Color(0xFF7C3AED),
      quickStats: const ['Classroom', 'Assessments', 'Progress'],
      children: [
        if (canAccess('attendance'))
        DashboardActionCard(
          icon: Icons.check_box,
          title: 'Attendance',
          subtitle: 'Mark attendance and review class trends.',
          accentColor: const Color(0xFF7C3AED),
          onTap: () => Navigator.pushNamed(context, '/attendance_home'),
        ),
        if (canAccess('homework'))
        DashboardActionCard(
          icon: Icons.assignment_turned_in,
          title: 'Homework',
          subtitle: 'Create assignments and track submissions.',
          accentColor: const Color(0xFF8B5CF6),
          onTap: () => Navigator.pushNamed(context, '/homework'),
        ),
        if (canAccess('assessments'))
        DashboardActionCard(
          icon: Icons.school,
          title: 'Assessments',
          subtitle: 'Publish tests and record student scores.',
          accentColor: const Color(0xFF6D28D9),
          onTap: () => Navigator.pushNamed(context, '/exam_management'),
        ),
        if (canAccess('result'))
        DashboardActionCard(
          icon: Icons.fact_check,
          title: 'Result',
          subtitle: 'Enter unit, half yearly and yearly exam marks for each class.',
          accentColor: const Color(0xFF9333EA),
          onTap: () => Navigator.pushNamed(context, '/result'),
        ),
        if (canAccess('notice_board'))
        DashboardActionCard(
          icon: Icons.campaign,
          title: 'Notice Board',
          subtitle: 'View campus notices and important updates.',
          accentColor: const Color(0xFF0EA5E9),
          onTap: () => Navigator.pushNamed(context, '/notice_board'),
        ),
        if (canAccess('learning'))
        DashboardActionCard(
          icon: Icons.school_outlined,
          title: 'Learning',
          subtitle: 'Open assigned and shared learning videos for students and staff.',
          accentColor: const Color(0xFF14B8A6),
          onTap: () => Navigator.pushNamed(context, '/learning'),
        ),
        if (canAccess('paper'))
        DashboardActionCard(
          icon: Icons.description,
          title: 'Paper',
          subtitle: 'Generate and share question papers as watermarked PDFs.',
          accentColor: const Color(0xFFDC2626),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaperScreen())),
        ),
        if (canAccess('messages'))
        DashboardActionCard(
          icon: Icons.message,
          title: 'Messages',
          subtitle: 'Communicate with students and parents.',
          accentColor: const Color(0xFFEC4899),
        ),
        if (canAccess('timetable'))
        DashboardActionCard(
          icon: Icons.calendar_today,
          title: 'Timetable',
          subtitle: 'View your daily schedule.',
          accentColor: const Color(0xFFF59E0B),
        ),
      ],
    );
  }
}

class ParentDashboard extends StatelessWidget {
  const ParentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      title: 'Parent Portal',
      description: 'Follow your child’s attendance, homework, and school announcements.',
      accentColor: const Color(0xFF16A34A),
      quickStats: const ['Home', 'Progress', 'Updates'],
      children: [
        const DashboardActionCard(
          icon: Icons.family_restroom,
          title: 'Child Attendance',
          subtitle: 'Monitor daily attendance and trends.',
          accentColor: Color(0xFF16A34A),
        ),
        DashboardActionCard(
          icon: Icons.book,
          title: 'Homework Updates',
          subtitle: 'See assignments and deadlines.',
          accentColor: const Color(0xFF22C55E),
          onTap: () => Navigator.pushNamed(context, '/homework'),
        ),
        DashboardActionCard(
          icon: Icons.grade,
          title: 'Academic Progress',
          subtitle: 'Review test results and grades.',
          accentColor: const Color(0xFF10B981),
          onTap: () => Navigator.pushNamed(context, '/exam_results'),
        ),
        DashboardActionCard(
          icon: Icons.campaign,
          title: 'Notice Board',
          subtitle: 'Receive school announcements and alerts.',
          accentColor: const Color(0xFF0EA5E9),
          onTap: () => Navigator.pushNamed(context, '/notice_board'),
        ),
        DashboardActionCard(
          icon: Icons.school_outlined,
          title: 'Learning',
          subtitle: 'View shared learning videos and educational resources.',
          accentColor: const Color(0xFF14B8A6),
          onTap: () => Navigator.pushNamed(context, '/learning'),
        ),
      ],
    );
  }
}

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      title: 'Student Hub',
      description: 'Access your schedule, homework, results, and school updates.',
      accentColor: const Color(0xFF2563EB),
      quickStats: const ['Schedule', 'Results', 'Learning'],
      children: [
        const DashboardActionCard(
          icon: Icons.schedule,
          title: 'Class Schedule',
          subtitle: 'View today’s classes and timings.',
        ),
        DashboardActionCard(
          icon: Icons.assignment,
          title: 'Homework',
          subtitle: 'Track assignments and submission status.',
          onTap: () => Navigator.pushNamed(context, '/homework'),
        ),
        DashboardActionCard(
          icon: Icons.assessment,
          title: 'Results',
          subtitle: 'See test scores and academic feedback.',
          onTap: () => Navigator.pushNamed(context, '/exam_results'),
        ),
        DashboardActionCard(
          icon: Icons.campaign,
          title: 'Notice Board',
          subtitle: 'Stay updated with school news.',
          onTap: () => Navigator.pushNamed(context, '/notice_board'),
        ),
        DashboardActionCard(
          icon: Icons.school_outlined,
          title: 'Learning',
          subtitle: 'Watch school learning videos and study resources.',
          onTap: () => Navigator.pushNamed(context, '/learning'),
        ),
      ],
    );
  }
}

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot = await _firestore.collection('users').orderBy('displayName').get();
      setState(() {
        _users = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['displayName'] ?? 'Unnamed User',
            'email': data['email'] ?? 'N/A',
            'role': data['role'] ?? 'student',
            'class': data['studentClassId'] != null ? '${data['studentClassId']}-${data['studentSection'] ?? ''}' : 'N/A',
            'accessPermissions': List<String>.from(data['accessPermissions'] ?? const <String>[]),
          };
        }).toList();
      });
    } catch (_) {
      setState(() {
        _users = const [];
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final user = _users[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        ((user['name'] as String?) ?? 'U').trim().isEmpty
                            ? 'U'
                            : ((user['name'] as String?) ?? 'U').trim()[0].toUpperCase(),
                      ),
                    ),
                    title: Text((user['name'] as String?)?.trim().isNotEmpty == true ? user['name'] as String : 'Unnamed User'),
                    subtitle: Text('${user['email'] ?? 'N/A'}\nRole: ${user['role'] ?? 'student'}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.admin_panel_settings),
                      tooltip: 'Change access',
                      onPressed: () => _showAccessDialog(user),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _showAccessDialog(Map<String, dynamic> user) async {
    const permissions = <String, String>{
      'attendance': 'Attendance',
      'homework': 'Homework',
      'assessments': 'Assessments',
      'result': 'Results',
      'notice_board': 'Notice Board',
      'learning': 'Learning',
      'paper': 'Paper',
      'messages': 'Messages',
      'timetable': 'Timetable',
    };
    final selected = <String>{...(user['accessPermissions'] as List<String>? ?? const <String>[])};
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Access: ${user['name']}'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: permissions.entries.map((entry) {
                return CheckboxListTile(
                  dense: true,
                  title: Text(entry.value),
                  value: selected.contains(entry.key),
                  onChanged: (value) => setDialogState(() {
                    if (value == true) {
                      selected.add(entry.key);
                    } else {
                      selected.remove(entry.key);
                    }
                  }),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _firestore.collection('users').doc(user['id'] as String).update({
                'accessPermissions': selected.toList(),
                'accessUpdatedAt': FieldValue.serverTimestamp(),
              });
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              await _loadUsers();
            },
            child: const Text('Save access'),
          ),
        ],
      ),
    );
  }
}

class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _teachers = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final classSnapshot = await _firestore.collection('classes').get();
      final studentSnapshot = await _firestore.collection('students').get();
      final userSnapshot = await _firestore.collection('users').get();
      final counts = <String, int>{};
      final classData = <String, Map<String, dynamic>>{};
      final teachers = userSnapshot.docs
          .map((doc) {
            final data = doc.data();
            final role = (data['role'] ?? data['normalizedRole'] ?? '').toString().toLowerCase();
            if (role != 'teacher') return null;
            return {
              'id': doc.id,
              'name': (data['displayName'] ?? '').toString().trim(),
              'email': (data['email'] ?? '').toString().trim(),
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList()
        ..sort((a, b) => _displayUserName(a).compareTo(_displayUserName(b)));
      for (final doc in classSnapshot.docs) {
        final data = doc.data();
        final classId = (data['classId'] ?? '').toString().trim();
        final section = (data['section'] ?? '').toString().trim();
        if (classId.isEmpty || section.isEmpty) continue;
        classData['$classId-$section'] = {
          'name': data['className'] ?? classId,
          'section': section,
          'teacherId': (data['teacherId'] ?? '').toString(),
        };
      }
      for (final doc in studentSnapshot.docs) {
        final data = doc.data();
        final classId = (data['classId'] ?? '').toString().trim();
        final section = (data['section'] ?? '').toString().trim();
        if (classId.isEmpty || section.isEmpty) continue;
        final key = '$classId-$section';
        counts[key] = (counts[key] ?? 0) + 1;
        classData.putIfAbsent(key, () => {'name': classId, 'section': section, 'teacherId': ''});
      }

      setState(() {
        _teachers = teachers;
        _classes = classData.entries
            .map((entry) => {
                  'id': entry.key,
                  'name': '${entry.value['name']}-${entry.value['section']}',
                  'count': counts[entry.key] ?? 0,
                  'teacherName': _teacherNameById(teachers, entry.value['teacherId'] as String?),
                })
            .toList()
          ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      });
    } catch (_) {
      setState(() => _classes = const []);
    } finally {
      setState(() => _loading = false);
    }
  }

  static String _displayUserName(Map<String, dynamic> user) {
    final name = (user['name'] as String? ?? '').trim();
    final email = (user['email'] as String? ?? '').trim();
    return name.isNotEmpty ? name : email.isNotEmpty ? email : 'Unnamed Teacher';
  }

  static String _teacherNameById(List<Map<String, dynamic>> teachers, String? teacherId) {
    if (teacherId == null || teacherId.isEmpty) return 'Not assigned';
    Map<String, dynamic>? teacher;
    for (final item in teachers) {
      if (item['id'] == teacherId) {
        teacher = item;
        break;
      }
    }
    return teacher == null ? 'Not assigned' : _displayUserName(teacher);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes & Sections'),
        actions: [
          IconButton(
            tooltip: 'Create class',
            icon: const Icon(Icons.add),
            onPressed: _showCreateClassDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: _classes.isEmpty
                  ? const Center(child: Text('No class sections found.'))
                  : LayoutBuilder(
                      builder: (context, constraints) => GridView.builder(
                        itemCount: _classes.length,
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: constraints.maxWidth >= 900 ? 360 : 520,
                          mainAxisExtent: 210,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemBuilder: (context, index) {
                          final item = _classes[index];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'],
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('${item['count']} students'),
                                  const SizedBox(height: 4),
                                  Text('Teacher: ${item['teacherName']}'),
                                  const Spacer(),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () => _showAssignTeacherDialog(item),
                                      icon: const Icon(Icons.person_add_alt_1),
                                      label: const Text('Assign teacher'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
    );
  }

  Future<void> _showCreateClassDialog() async {
    final classIdController = TextEditingController();
    final classNameController = TextEditingController();
    final sectionController = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Create Class & Section'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: classIdController, decoration: const InputDecoration(labelText: 'Class ID (e.g. 10)')),
              TextField(controller: classNameController, decoration: const InputDecoration(labelText: 'Class name')),
              TextField(controller: sectionController, decoration: const InputDecoration(labelText: 'Section (e.g. A)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final classId = classIdController.text.trim();
                final className = classNameController.text.trim().isEmpty ? classId : classNameController.text.trim();
                final section = sectionController.text.trim();
                if (classId.isEmpty || section.isEmpty) return;
                await _firestore.collection('classes').doc('$classId-$section').set({
                  'classId': classId,
                  'className': className,
                  'section': section,
                  'teacherId': '',
                  'teacherName': 'Not assigned',
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                await _loadClasses();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      );
    } finally {
      classIdController.dispose();
      classNameController.dispose();
      sectionController.dispose();
    }
  }

  Future<void> _showAssignTeacherDialog(Map<String, dynamic> item) async {
    if (!mounted) return;
    if (_teachers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No teachers found.')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Assign teacher to ${item['name']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: _teachers.map((teacher) {
              final teacherId = teacher['id'] as String;
              final name = _displayUserName(teacher);
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(name),
                onTap: () async {
                  final classKey = item['id'] as String;
                  final parts = classKey.split('-');
                  final classId = parts.first;
                  final section = parts.length > 1 ? parts.sublist(1).join('-') : '';
                  await _firestore.collection('classes').doc(classKey).set({
                    'classId': classId,
                    'section': section,
                    'teacherId': teacherId,
                    'teacherName': name,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                  final teacherRef = _firestore.collection('users').doc(teacherId);
                  final teacherSnapshot = await teacherRef.get();
                  final existing = List<String>.from(teacherSnapshot.data()?['assignedClassSections'] ?? const <String>[]);
                  if (!existing.contains(classKey)) existing.add(classKey);
                  await teacherRef.set({'assignedClassSections': existing}, SetOptions(merge: true));
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  await _loadClasses();
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
