import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:udaan_campus/models/student.dart';
import 'package:udaan_campus/services/qr_service.dart';
import 'package:udaan_campus/services/auth_provider.dart';
import 'package:udaan_campus/models/user_role.dart';

class StudentQrScreen extends StatefulWidget {
  const StudentQrScreen({super.key, required this.studentId});

  final String studentId;

  @override
  State<StudentQrScreen> createState() => _StudentQrScreenState();
}

class _StudentQrScreenState extends State<StudentQrScreen> {
  final QrService _qrService = QrService();
  final GlobalKey _cardKey = GlobalKey();
  Student? _student;
  String? _qrToken;
  bool _loading = true;
  bool _regenerating = false;
  bool _printing = false;
  bool _sharing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStudentQr();
  }

  Future<void> _loadStudentQr() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final student = await _qrService.getStudentById(widget.studentId);
      if (student == null) {
        setState(() {
          _error = 'Student not found.';
          _loading = false;
        });
        return;
      }
      final token = student.qrToken;
      setState(() {
        _student = student;
        _qrToken = token;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load student QR details.';
        _loading = false;
      });
    }
  }

  Future<void> _regenerateQr() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null || !UserRole.isAtLeastManager(user.role)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only managers can regenerate QR tokens.')));
      return;
    }

    setState(() {
      _regenerating = true;
      _error = null;
    });

    try {
      final token = await _qrService.regenerateStudentQrToken(
        studentId: widget.studentId,
        performedBy: user.uid,
      );
      setState(() {
        _qrToken = token;
        _regenerating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR token regenerated successfully.')));
      }
    } catch (e) {
      setState(() {
        _error = 'Unable to regenerate QR token.';
        _regenerating = false;
      });
    }
  }

  Future<void> _shareIdCard() async {
    if (_student == null || _qrToken == null) return;

    try {
      setState(() => _sharing = true);
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        await SharePlus.instance.share(
          ShareParams(
            text: 'Student ID Card\nName: ${_student!.name}\nClass: ${_student!.classId ?? 'N/A'}-${_student!.section ?? 'N/A'}\nRoll: ${_student!.rollNumber}\nStudent ID: ${_student!.id}\nQR Token: $_qrToken',
            subject: 'Udaan Academy Student ID Card',
          ),
        );
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Unable to generate ID card image.');
      }

      final tempFile = File('${Directory.systemTemp.path}/udaan_student_id_${_student!.id}.png');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          text: 'Student ID Card for ${_student!.name}',
          subject: 'Udaan Academy Student ID Card',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to share the ID card.')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _printIdCard() async {
    if (_student == null || _qrToken == null) return;

    try {
      setState(() => _printing = true);
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Center(
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
                    color: PdfColors.white,
                    border: pw.Border.all(color: PdfColors.blue900, width: 2),
                  ),
                  width: 440,
                  padding: const pw.EdgeInsets.all(20),
                  child: pw.Column(
                    children: [
                      pw.Text('Udaan Academy', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.SizedBox(height: 6),
                      pw.Text('Student ID Card', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 20),
                      pw.Row(
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(_student!.name, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 8),
                              pw.Text('Father: ${_student!.fatherName ?? _student!.parentName ?? 'N/A'}'),
                              pw.Text('Class: ${_student!.classId ?? 'N/A'} - ${_student!.section ?? 'N/A'}'),
                              pw.Text('School: Udaan Academy'),
                              pw.Text('Phone: ${_student!.parentPhone ?? 'N/A'}'),
                            ],
                          ),
                          pw.SizedBox(width: 20),
                          pw.Column(
                            children: [
                              pw.Container(
                                width: 120,
                                height: 120,
                                child: pw.BarcodeWidget(
                                  barcode: pw.Barcode.qrCode(),
                                  data: _qrToken!,
                                  width: 120,
                                  height: 120,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to print the ID card.')));
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student QR Card')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _student == null
                    ? const Center(child: Text('Student data unavailable.'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RepaintBoundary(
                            key: _cardKey,
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade900,
                                      Colors.indigo.shade700,
                                    ],
                                  ),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Udaan Academy', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text('Student ID Card', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundColor: Colors.white,
                                          backgroundImage: _student!.profileImage != null && _student!.profileImage!.isNotEmpty
                                              ? NetworkImage(_student!.profileImage!)
                                              : null,
                                          child: _student!.profileImage == null || _student!.profileImage!.isEmpty
                                              ? Icon(Icons.person, size: 28, color: Colors.blue.shade900)
                                              : null,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(_student!.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 8),
                                                Text('Father: ${_student!.fatherName ?? _student!.parentName ?? 'N/A'}', style: const TextStyle(color: Colors.white)),
                                                Text('Class: ${_student!.classId ?? 'N/A'} - ${_student!.section ?? 'N/A'}', style: const TextStyle(color: Colors.white)),
                                                const Text('Udaan Academy', style: TextStyle(color: Colors.white)),
                                                Text('Mobile: ${_student!.parentPhone ?? 'N/A'}', style: const TextStyle(color: Colors.white)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          if (_qrToken != null)
                                            QrImageView(
                                              data: _qrToken!,
                                              version: QrVersions.auto,
                                              size: 110,
                                              backgroundColor: Colors.white,
                                              errorStateBuilder: (context, err) => const Center(child: Text('QR')),
                                            )
                                          else
                                            const SizedBox(width: 110, height: 110, child: Center(child: Text('QR'))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (_qrToken != null)
                                      SelectableText(
                                        _qrToken!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _printing ? null : _printIdCard,
                                  icon: const Icon(Icons.print),
                                  label: _printing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Print ID Card'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _sharing ? null : _shareIdCard,
                                  icon: const Icon(Icons.share),
                                  label: _sharing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Share ID Card'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _regenerating ? null : _regenerateQr,
                            child: _regenerating
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Refresh QR'),
                          ),
                        ],
                      ),
      ),
    );
  }
}
