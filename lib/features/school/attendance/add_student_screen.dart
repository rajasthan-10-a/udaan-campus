import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:udaan_campus/services/auth_provider.dart';
import 'package:udaan_campus/services/qr_service.dart';
import 'package:udaan_campus/services/supabase_storage_service.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _qrService = QrService();
  final _name = TextEditingController();
  final _father = TextEditingController();
  final _mother = TextEditingController();
  final _mobile = TextEditingController();
  final _srNumber = TextEditingController();
  final _dobWords = TextEditingController();
  final _fees = TextEditingController();
  final _roll = TextEditingController();
  final _email = TextEditingController();
  final _occupation = TextEditingController();
  final _photoUrl = TextEditingController();
  DateTime? _dob;
  String? _classSection;
  String _occupationType = 'Government';
  bool _rte = false;
  bool _active = true;
  bool _saving = false;
  PlatformFile? _photo;
  List<String> _classSections = [];

  @override
  void initState() {
    super.initState();
    _loadClassSections();
  }

  Future<void> _loadClassSections() async {
    final classes = await _firestore.collection('classes').get();
    final sections = classes.docs.map((doc) {
      final data = doc.data();
      final classId = (data['classId'] ?? '').toString().trim();
      final section = (data['section'] ?? '').toString().trim();
      return classId.isEmpty || section.isEmpty ? '' : '$classId-$section';
    }).where((value) => value.isNotEmpty).toSet().toList()..sort();
    if (mounted) setState(() => _classSections = sections);
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.pickFile(type: FileType.image);
    if (result != null && mounted) setState(() => _photo = result);
  }

  Future<void> _pickDob() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 3650)),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) {
      setState(() => _dob = date);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _classSection == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields.')));
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final parts = _classSection!.split('-');
      final id = _firestore.collection('students').doc().id;
      String? photoUrl = _photoUrl.text.trim().isEmpty ? null : _photoUrl.text.trim();
      if (_photo != null) {
        photoUrl = await SupabaseStorageService().uploadFile(
          file: _photo!,
          bucket: 'student-photos',
          folder: 'students',
        );
      }
      final ref = _firestore.collection('students').doc(id);
      await ref.set({
        'name': _name.text.trim(),
        'fatherName': _father.text.trim(),
        'parentName': _father.text.trim(),
        'motherName': _mother.text.trim(),
        'parentPhone': _mobile.text.trim(),
        'rollNumber': _roll.text.trim(),
        'srNumber': _srNumber.text.trim(),
        'classId': parts.first,
        'section': parts.sublist(1).join('-'),
        'department': parts.first,
        'semester': '',
        'email': _email.text.trim(),
        'cgpa': 0,
        'dateOfBirth': _dob?.toIso8601String(),
        'dateOfBirthWords': _dobWords.text.trim(),
        'rte': _rte,
        if (!_rte) 'fees': double.tryParse(_fees.text.trim()) ?? 0,
        'fatherOccupation': _occupationType,
        'occupationDetails': _occupation.text.trim(),
        'profileImage': photoUrl,
        'active': _active,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
      });
      await _qrService.createStudentQrToken(studentId: id, performedBy: user.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student added with QR code.')));
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to add student: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _father, _mother, _mobile, _srNumber, _dobWords, _fees, _roll, _email, _occupation, _photoUrl]) {
      controller.dispose();
    }
    super.dispose();
  }

  InputDecoration _decoration(String label) => InputDecoration(labelText: label, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Student')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: _name, decoration: _decoration('Student name *'), validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _father, decoration: _decoration('Father name *'), validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _mother, decoration: _decoration('Mother name')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _classSection,
              decoration: _decoration('Class & section *'),
              items: _classSections.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) => setState(() => _classSection = value),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _mobile, decoration: _decoration('Mobile number *'), keyboardType: TextInputType.phone, validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _srNumber, decoration: _decoration('S.R. number')),
            const SizedBox(height: 12),
            TextFormField(controller: _roll, decoration: _decoration('Roll number')),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_dob == null ? 'Date of birth' : '${_dob!.day}/${_dob!.month}/${_dob!.year}'),
              trailing: const Icon(Icons.calendar_month),
              onTap: _pickDob,
            ),
            TextFormField(controller: _dobWords, decoration: _decoration('Date of birth in words')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _occupationType,
              decoration: _decoration('Father occupation'),
              items: const [
                DropdownMenuItem(value: 'Government', child: Text('Government')),
                DropdownMenuItem(value: 'Non-government', child: Text('Non-government')),
              ],
              onChanged: (value) => setState(() => _occupationType = value ?? 'Government'),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _occupation, decoration: _decoration('Occupation details')),
            const SizedBox(height: 12),
            SwitchListTile(title: const Text('RTE student'), value: _rte, onChanged: (value) => setState(() => _rte = value)),
            if (!_rte) TextFormField(controller: _fees, decoration: _decoration('Fees'), keyboardType: TextInputType.number),
            SwitchListTile(title: const Text('Active student'), value: _active, onChanged: (value) => setState(() => _active = value)),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _pickPhoto, icon: const Icon(Icons.photo), label: Text(_photo == null ? 'Add photo' : _photo!.name)),
            TextFormField(controller: _photoUrl, decoration: _decoration('Photo URL (optional)')),
            TextFormField(controller: _email, decoration: _decoration('Email (optional)'), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'Saving...' : 'Save Student & Create QR'),
            ),
          ],
        ),
      ),
    );
  }
}
