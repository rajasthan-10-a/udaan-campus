import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class PaperScreen extends StatefulWidget {
  const PaperScreen({super.key});

  @override
  State<PaperScreen> createState() => _PaperScreenState();
}

class _PaperScreenState extends State<PaperScreen> {
  final _contentController = TextEditingController();
  final _marksController = TextEditingController(text: '50');
  final _titleController = TextEditingController(text: 'Assessment Paper');
  PlatformFile? _sourceFile;
  String _difficulty = 'Moderate';
  bool _generating = false;
  List<_PaperQuestion> _questions = [];

  @override
  void dispose() {
    _contentController.dispose();
    _marksController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickSource() async {
    final result = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg']);
    if (result != null && mounted) setState(() => _sourceFile = result);
  }

  void _generateQuestions() {
    final totalMarks = int.tryParse(_marksController.text.trim()) ?? 0;
    if (totalMarks <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid total marks.')));
      return;
    }
    final source = _contentController.text
        .split(RegExp(r'[\n.!?]+'))
        .map((line) => line.trim())
        .where((line) => line.length > 8)
        .toList();
    if (source.isEmpty && _sourceFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paste content or attach a PDF/image first.')));
      return;
    }
    final seeds = source.isEmpty
        ? <String>[
            'Explain the main topic from the attached source material: ${_sourceFile?.name ?? 'provided content'}.',
          ]
        : source;
    final questions = <_PaperQuestion>[];
    var remaining = totalMarks;
    void add(String type, String question, int marks) {
      if (remaining < marks) return;
      questions.add(_PaperQuestion(type: type, question: question, marks: marks));
      remaining -= marks;
    }
    final objectiveMarks = totalMarks >= 20 ? 1 : 1;
    for (var i = 0; i < seeds.length && questions.length < 5; i++) {
      add('Objective', 'Choose the correct answer related to: ${seeds[i]}', objectiveMarks);
    }
    for (var i = 0; i < seeds.length && questions.where((q) => q.type == 'Fill in the blanks').length < 3; i++) {
      add('Fill in the blanks', 'Fill in the blank: ${seeds[i]} ________.', 1);
    }
    final shortMarks = _difficulty == 'Easy' ? 2 : _difficulty == 'Hard' ? 4 : 3;
    for (var i = 0; i < seeds.length && questions.where((q) => q.type == 'Short answer').length < 3; i++) {
      add('Short answer', 'Write a short answer about: ${seeds[i]}', shortMarks);
    }
    final longMarks = _difficulty == 'Easy' ? 5 : _difficulty == 'Hard' ? 10 : 8;
    for (var i = 0; i < seeds.length && remaining >= longMarks; i++) {
      add('Long answer', 'Explain in detail: ${seeds[i]}', longMarks);
    }
    while (remaining > 0) {
      final marks = remaining >= 2 ? 2 : 1;
      add('Short answer', 'Answer briefly from the supplied study material.', marks);
    }
    setState(() => _questions = questions);
  }

  Future<void> _sharePdf() async {
    if (_questions.isEmpty) {
      _generateQuestions();
    }
    if (_questions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generate questions before creating the PDF.')));
      }
      return;
    }
    setState(() => _generating = true);
    try {
      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.all(36),
            buildBackground: (context) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Transform.rotate(
                  angle: -0.45,
                  child: pw.Opacity(
                    opacity: 0.12,
                    child: pw.Text('UDAAN ACADEMY', style: pw.TextStyle(fontSize: 44, fontWeight: pw.FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Udaan Academy', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.Text(_titleController.text.trim(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Total Marks: ${_marksController.text}    Difficulty: $_difficulty'),
              pw.Divider(),
            ],
          ),
          build: (context) => [
            for (var i = 0; i < _questions.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text('${i + 1}. [${_questions[i].type}] ${_questions[i].question} (${_questions[i].marks})'),
              ),
          ],
        ),
      );
      final file = File('${Directory.systemTemp.path}/udaan_paper_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await document.save());
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: _titleController.text.trim()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Watermarked paper PDF created successfully.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to create paper PDF: $error')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paper Generator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Paper title', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _marksController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total marks', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _difficulty,
            decoration: const InputDecoration(labelText: 'Question difficulty', border: OutlineInputBorder()),
            items: const ['Easy', 'Moderate', 'Hard'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
            onChanged: (value) => setState(() => _difficulty = value ?? 'Moderate'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Paste chapter/content text',
              hintText: 'Paste the source content here for question generation.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _pickSource, icon: const Icon(Icons.attach_file), label: Text(_sourceFile == null ? 'Attach PDF or photo' : _sourceFile!.name)),
          const SizedBox(height: 12),
          ElevatedButton.icon(onPressed: _generateQuestions, icon: const Icon(Icons.auto_awesome), label: const Text('Generate Questions')),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _generating ? null : _sharePdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(_generating ? 'Preparing PDF...' : 'Create Watermarked PDF & Share'),
          ),
          if (_questions.isNotEmpty) ...[
            const SizedBox(height: 16),
            ..._questions.asMap().entries.map((entry) => Card(
                  child: ListTile(
                    title: Text('${entry.key + 1}. ${entry.value.type}'),
                    subtitle: Text(entry.value.question),
                    trailing: Text('${entry.value.marks}'),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _PaperQuestion {
  const _PaperQuestion({required this.type, required this.question, required this.marks});
  final String type;
  final String question;
  final int marks;
}
