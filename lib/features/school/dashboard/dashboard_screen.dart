import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:udaan_campus/models/user_role.dart';
import 'package:udaan_campus/services/auth_provider.dart';

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
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: UdaanLogoMark(size: 34),
        ),
        title: Text(title),
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
            Text(description, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (user != null)
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.primaryContainer.withAlpha(150),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    child: Text(user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : user.role[0].toUpperCase()),
                  ),
                  title: Text(user.displayName.isNotEmpty ? user.displayName : user.email),
                  subtitle: Text('Role: ${user.role}'),
                ),
              ),
              if (user?.role == UserRole.student || user?.role == UserRole.teacher)
                const Padding(
                  padding: EdgeInsets.only(top: 16, bottom: 4),
                  child: MotivationCarousel(),
                ),
              const SizedBox(height: 8),
            Expanded(
              child: GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 3,
                children: children,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Developed by Udaan Academy',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xff53627c)),
            ),
            const Text(
              'Umesh Sharma  |  Bharatpur, Rajasthan  |  9785705358',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xff7c879c)),
            ),
            const SizedBox(height: 8),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primary.withAlpha((0.12 * 255).round()),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
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
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

void _openFeatureInfo(BuildContext context, String title, String description) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => FeatureInfoScreen(title: title, description: description),
    ),
  );
}

class FeatureInfoScreen extends StatelessWidget {
  const FeatureInfoScreen({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const UdaanLogoMark(size: 72),
              const SizedBox(height: 20),
              Text(title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
              const SizedBox(height: 12),
              Text(description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UdaanLogoMark extends StatelessWidget {
  const UdaanLogoMark({super.key, this.size = 54});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .28),
          gradient: const LinearGradient(
            colors: [Color(0xff175bd1), Color(0xff12a5a0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x33175bd1),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.menu_book_rounded, size: size * .54, color: Colors.white),
            Positioned(
              top: size * .12,
              right: size * .1,
              child: Icon(Icons.flight_takeoff_rounded, size: size * .24, color: Colors.white),
            ),
          ],
        ),
    );
  }
}

class MotivationCarousel extends StatefulWidget {
  const MotivationCarousel({super.key});

    @override
  State<MotivationCarousel> createState() => _MotivationCarouselState();
}

class _MotivationCarouselState extends State<MotivationCarousel> {
  static const _slides = [
      ('Believe in yourself', 'Every big achievement starts with one brave step.', 'photo-1497633762265-9d179a990aa6'),
      ('Learn something new', 'Knowledge grows when curiosity leads the way.', 'photo-1503676260728-1c00da094a0b'),
      ('Dream. Plan. Achieve.', 'Your consistent effort is building your future.', 'photo-1523240795612-9a054b0db644'),
      ('Stay focused', 'Small daily progress creates extraordinary results.', 'photo-1434030216411-0b793f4b4173'),
      ('Be wonderfully curious', 'Questions are the beginning of every discovery.', 'photo-1531482615713-2afd69097998'),
      ('Kindness is strength', 'Lift others while you rise.', 'photo-1509062522246-3755977927d7'),
      ('Your time is now', 'Do not wait for the perfect moment to begin.', 'photo-1516321318423-f06f85e504b3'),
      ('Practice makes progress', 'Keep showing up. Your future self will thank you.', 'photo-1541339907198-e08756dedf3f'),
      ('Think beyond limits', 'A creative mind can find a way forward.', 'photo-1453738773917-dcbc65e6ff1b'),
      ('Make today count', 'Give your best to the opportunity in front of you.', 'photo-1522202176988-66273c2fd55f'),
    ];
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
      super.initState();
      _controller = PageController();
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        _page = (_page + 1) % _slides.length;
        _controller.animateToPage(
          _page,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
        );
      });
  }

  @override
  void dispose() {
      _timer?.cancel();
      _controller.dispose();
      super.dispose();
  }

  @override
  Widget build(BuildContext context) {
      return SizedBox(
        height: 164,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        'https://images.unsplash.com/${slide.$2}?auto=format&fit=crop&w=1200&q=80',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xff175bd1), Color(0xff12a5a0)],
                            ),
                          ),
                        ),
                      ),
                      Container(color: Colors.black.withAlpha(105)),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: .78,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(slide.$1,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    )),
                                const SizedBox(height: 6),
                                Text(slide.$3,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.3,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              Positioned(
                left: 20,
                bottom: 12,
                child: Row(
                  children: List.generate(
                    _slides.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 4),
                      width: index == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(index == _page ? 240 : 130),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
      children: [
        DashboardActionCard(
          icon: Icons.people,
          title: 'User Management',
          subtitle: 'Add or update teachers, parents and students.',
          onTap: () => Navigator.pushNamed(context, '/create_parent_account'),
        ),
        DashboardActionCard(
          icon: Icons.badge,
          title: 'Student ID Cards',
          subtitle: 'Create QR ID cards with family details.',
          onTap: () => Navigator.pushNamed(context, '/attendance_home'),
        ),
        DashboardActionCard(
          icon: Icons.family_restroom,
          title: 'Create Parent Account',
          subtitle: 'Create a parent login and link a student.',
          onTap: () => Navigator.pushNamed(context, '/create_parent_account'),
        ),
        DashboardActionCard(
          icon: Icons.class_,
          title: 'Classes & Sections',
          subtitle: 'Create classes, assign teachers and review schedules.',
          onTap: () => _openFeatureInfo(
            context,
            'Classes & Sections',
            'Class and section management is available through the manager workspace. '
                'Use the assigned class tools to review current sections.',
          ),
        ),
        DashboardActionCard(
          icon: Icons.event_available,
          title: 'Attendance',
          subtitle: 'Monitor attendance across the school.',
          onTap: () => Navigator.pushNamed(context, '/attendance_home'),
        ),
        DashboardActionCard(
          icon: Icons.assignment,
          title: 'Homework',
          subtitle: 'Track homework assignments and deadlines.',
          onTap: () => Navigator.pushNamed(context, '/homework'),
        ),
        DashboardActionCard(
          icon: Icons.notifications,
          title: 'Announcements',
          subtitle: 'Send school-wide notices and alerts.',
          onTap: () => _openFeatureInfo(
            context,
            'Announcements',
            'Announcements are shown to published student and parent portals. '
                'Publishing controls are being kept restricted to authorized staff.',
          ),
        ),
        DashboardActionCard(
          icon: Icons.analytics,
          title: 'Reports',
          subtitle: 'Review performance, logs, and audit activities.',
          onTap: () => Navigator.pushNamed(context, '/exam_results'),
        ),
        DashboardActionCard(
          icon: Icons.picture_as_pdf,
          title: 'Exam Papers',
          subtitle: 'Upload and download paper PDFs.',
          onTap: () => Navigator.pushNamed(context, '/exam_papers'),
        ),
        DashboardActionCard(
          icon: Icons.auto_awesome,
          title: 'AI Paper Builder',
          subtitle: 'Create reviewable questions from content and share drafts.',
          onTap: () => Navigator.pushNamed(context, '/paper_builder'),
        ),
        DashboardActionCard(
          icon: Icons.menu_book,
          title: 'Courses & Learning',
          subtitle: 'Manage courses, videos, resources, and mock tests.',
          onTap: () => Navigator.pushNamed(context, '/courses'),
        ),
      ],
    );
  }
}

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      title: 'Teacher Panel',
      description: 'Manage classes, attendance, homework, and student progress.',
      children: [
        DashboardActionCard(
          icon: Icons.check_box,
          title: 'Attendance',
          subtitle: 'Mark attendance and review class trends.',
          onTap: () => Navigator.pushNamed(context, '/attendance_home'),
        ),
        DashboardActionCard(
          icon: Icons.assignment_turned_in,
          title: 'Homework',
          subtitle: 'Create assignments and track submissions.',
          onTap: () => Navigator.pushNamed(context, '/homework'),
        ),
        DashboardActionCard(
          icon: Icons.school,
          title: 'Assessments',
          subtitle: 'Publish tests and record student scores.',
          onTap: () => Navigator.pushNamed(context, '/exam_management'),
        ),
        DashboardActionCard(
          icon: Icons.assessment,
          title: 'Class Marksheets',
          subtitle: 'Review marks and results for your assigned class.',
          onTap: () => Navigator.pushNamed(context, '/exam_results'),
        ),
        DashboardActionCard(
          icon: Icons.picture_as_pdf,
          title: 'Exam Papers',
          subtitle: 'Upload and download paper PDFs.',
          onTap: () => Navigator.pushNamed(context, '/exam_papers'),
        ),
        DashboardActionCard(
          icon: Icons.auto_awesome,
          title: 'AI Paper Builder',
          subtitle: 'Create reviewable questions from content and share drafts.',
          onTap: () => Navigator.pushNamed(context, '/paper_builder'),
        ),
        DashboardActionCard(
          icon: Icons.menu_book,
          title: 'Courses & Learning',
          subtitle: 'Open published courses and study resources.',
          onTap: () => Navigator.pushNamed(context, '/courses'),
        ),
        DashboardActionCard(
          icon: Icons.message,
          title: 'Messages',
          subtitle: 'Communicate with students and parents.',
          onTap: () => _openFeatureInfo(
            context,
            'Messages',
            'Use the linked student and homework workflows for verified school communication.',
          ),
        ),
        DashboardActionCard(
          icon: Icons.calendar_today,
          title: 'Timetable',
          subtitle: 'View your daily schedule.',
          onTap: () => _openFeatureInfo(
            context,
            'Timetable',
            'Your timetable will appear here when the school publishes class timings.',
          ),
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
      children: [
        DashboardActionCard(
          icon: Icons.verified_user,
          title: 'My Student Portal',
          subtitle: 'Verify your profile and view all live updates.',
          onTap: () => Navigator.pushNamed(context, '/student_portal'),
        ),
        DashboardActionCard(
          icon: Icons.family_restroom,
          title: 'Child Attendance',
          subtitle: 'Monitor daily attendance and trends.',
          onTap: () => Navigator.pushNamed(context, '/attendance_home'),
        ),
        DashboardActionCard(
          icon: Icons.book,
          title: 'Homework Updates',
          subtitle: 'See assignments and deadlines.',
          onTap: () => Navigator.pushNamed(context, '/homework'),
        ),
        DashboardActionCard(
          icon: Icons.grade,
          title: 'Academic Progress',
          subtitle: 'Review test results and grades.',
          onTap: () => Navigator.pushNamed(context, '/exam_results'),
        ),
        DashboardActionCard(
          icon: Icons.menu_book,
          title: 'Courses & Learning',
          subtitle: 'Study published courses and learning resources.',
          onTap: () => Navigator.pushNamed(context, '/courses'),
        ),
        DashboardActionCard(
          icon: Icons.notifications_active,
          title: 'Notifications',
          subtitle: 'Receive school announcements and alerts.',
          onTap: () => _openFeatureInfo(
            context,
            'Notifications',
            'Published school notices and important alerts will appear in your portal.',
          ),
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
      children: [
        DashboardActionCard(
          icon: Icons.schedule,
          title: 'Class Schedule',
          subtitle: 'View today’s classes and timings.',
          onTap: () => _openFeatureInfo(
            context,
            'Class Schedule',
            'Your school timetable will appear here when published by management.',
          ),
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
          icon: Icons.menu_book,
          title: 'Courses & Learning',
          subtitle: 'Study published courses and mock-test resources.',
          onTap: () => Navigator.pushNamed(context, '/courses'),
        ),
        DashboardActionCard(
          icon: Icons.notifications,
          title: 'Announcements',
          subtitle: 'Stay updated with school news.',
          onTap: () => _openFeatureInfo(
            context,
            'Announcements',
            'Published school announcements will appear here automatically.',
          ),
        ),
      ],
    );
  }
}
