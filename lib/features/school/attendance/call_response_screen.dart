import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:udaan_campus/models/calling_log_model.dart';
import 'package:udaan_campus/models/student.dart';
import 'package:udaan_campus/services/auth_provider.dart';
import 'package:udaan_campus/services/calling_log_service.dart';
import 'package:udaan_campus/utils/utils.dart';

class CallResponseScreen extends StatefulWidget {
  final Student student;
  final DateTime attendanceDate;

  const CallResponseScreen({super.key, required this.student, required this.attendanceDate});

  @override
  State<CallResponseScreen> createState() => _CallResponseScreenState();
}

class _CallResponseScreenState extends State<CallResponseScreen> {
  final CallingLogService _callingLogService = CallingLogService();
  final AudioRecorder _recorder = AudioRecorder();

  bool _loading = true;
  bool _saving = false;
  bool _isRecording = false;
  String _selectedOutcome = 'Connected';
  String _responseNotes = '';
  bool _followUpRequired = false;
  String _followUpNotes = '';
  DateTime? _followUpDate;
  String? _voiceNotePath;
  List<CallingLogModel> _callLogs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCallLogs();
  }

  Future<void> _loadCallLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final logs = await _callingLogService.getCallLogsForStudent(widget.student.id);
      setState(() {
        _callLogs = logs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load call history.';
        _loading = false;
      });
    }
  }

  Future<void> _recordCallAttempt({required String outcome, String? notes}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    final now = DateTime.now();
    final log = CallingLogModel(
      callId: CallingLogModel.buildCallId(widget.student.id, now),
      studentId: widget.student.id,
      studentName: widget.student.name,
      classId: widget.student.classId ?? '',
      className: widget.student.department,
      section: widget.student.section ?? '',
      attendanceDate: widget.attendanceDate,
      parentPhone: widget.student.parentPhone ?? '',
      parentName: widget.student.parentName,
      calledByUid: user.uid,
      calledByName: user.displayName,
      calledByRole: user.role,
      callOutcome: outcome,
      responseNotes: notes,
      followUpRequired: false,
      createdAt: now,
      updatedAt: now,
    );

    await _callingLogService.saveCallingLog(log);
    await _loadCallLogs();
  }

  Future<void> _callParent() async {
    await _launchParentChannel('call');
  }

  Future<void> _launchParentChannel(String channel) async {
    final phone = widget.student.parentPhone?.trim();
    if (phone == null || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parent phone number not available.')));
      return;
    }
    final message = Uri.encodeComponent(
      'Udaan Academy attendance update for ${widget.student.name}. Please contact the school for details.',
    );
    final uri = channel == 'call'
        ? Uri(scheme: 'tel', path: phone)
        : channel == 'whatsapp'
            ? Uri.parse('https://wa.me/${phone.replaceAll(RegExp(r'[^0-9]'), '')}?text=$message')
            : Uri.parse('sms:$phone?body=$message');
    final label = channel == 'call' ? 'Call' : channel == 'whatsapp' ? 'WhatsApp' : 'SMS';
    try {
      if (await canLaunchUrl(uri)) {
        await _recordCallAttempt(
          outcome: '$label Attempted',
          notes: '$label initiated to parent number $phone.',
        );
        if (!mounted) return;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await _recordCallAttempt(
          outcome: '$label Failed',
          notes: 'Unable to open $label for $phone.',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to open $label.')));
      }
    } catch (_) {
      await _recordCallAttempt(
        outcome: '$label Failed',
        notes: 'Exception while opening $label for $phone.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to open $label.')));
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _voiceNotePath = path;
      });
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission is required to record voice notes.')));
      return;
    }

    final directory = Directory.systemTemp;
    final filePath = '${directory.path}/udaan_call_${widget.student.id}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 2,
        ),
        path: filePath,
      );
      setState(() {
        _isRecording = true;
        _voiceNotePath = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to start recording.')));
    }
  }

  Future<String?> _uploadVoiceNoteIfNeeded(String callId) async {
    if (_voiceNotePath == null || _voiceNotePath!.isEmpty) return null;
    final file = File(_voiceNotePath!);
    if (!await file.exists()) return null;

    try {
      final storageRef = FirebaseStorage.instance.ref().child('voice_notes/$callId.m4a');
      final uploadTask = await storageRef.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<void> _selectFollowUpDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _followUpDate = date;
      });
    }
  }

  Future<void> _saveCallLog() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to determine user profile.')));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final callId = CallingLogModel.buildCallId(widget.student.id, now);
      final voiceNoteUrl = await _uploadVoiceNoteIfNeeded(callId);
      final log = CallingLogModel(
        callId: callId,
        studentId: widget.student.id,
        studentName: widget.student.name,
        classId: widget.student.classId ?? '',
        className: widget.student.department,
        section: widget.student.section ?? '',
        attendanceDate: widget.attendanceDate,
        parentPhone: widget.student.parentPhone ?? '',
        parentName: widget.student.parentName,
        calledByUid: user.uid,
        calledByName: user.displayName,
        calledByRole: user.role,
        callOutcome: _selectedOutcome,
        responseNotes: _responseNotes.isNotEmpty ? _responseNotes : null,
        followUpRequired: _followUpRequired,
        followUpNotes: _followUpRequired && _followUpNotes.isNotEmpty ? _followUpNotes : null,
        followUpDate: _followUpRequired ? _followUpDate : null,
        voiceNoteUrl: voiceNoteUrl,
        createdAt: now,
        updatedAt: now,
      );
      await _callingLogService.saveCallingLog(log);
      await _loadCallLogs();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Call details saved successfully.')));
      setState(() {
        _responseNotes = '';
        _followUpRequired = false;
        _followUpNotes = '';
        _followUpDate = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to save call log.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _buildCallHistory() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_callLogs.isEmpty) {
      return const Center(child: Text('No call history found for this student.'));
    }

    return ListView.separated(
      itemCount: _callLogs.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final log = _callLogs[index];
        return ListTile(
          title: Text(log.callOutcome),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateTimeUtils.formatDateTime(log.createdAt)),
              if (log.responseNotes != null) Text(log.responseNotes!),
              if (log.followUpRequired && log.followUpNotes != null) Text('Follow-up: ${log.followUpNotes}'),
              if (log.followUpDate != null) Text('Follow-up date: ${DateTimeUtils.formatDate(log.followUpDate!)}'),
            ],
          ),
          trailing: Icon(
            log.voiceNoteUrl != null ? Icons.mic : Icons.mic_none,
            color: log.voiceNoteUrl != null ? Colors.green : Colors.grey,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Absent Student Call Log')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.student.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Class: ${widget.student.classId ?? 'N/A'} - ${widget.student.section ?? 'N/A'}'),
                    Text('Absent Date: ${DateTimeUtils.formatDate(widget.attendanceDate)}'),
                    Text('Parent: ${widget.student.parentName ?? 'N/A'}'),
                    Text('Phone: ${widget.student.parentPhone ?? 'N/A'}'),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.call),
                          label: const Text('Call'),
                          onPressed: _callParent,
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.chat),
                          label: const Text('WhatsApp'),
                          onPressed: () => _launchParentChannel('whatsapp'),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.sms),
                          label: const Text('SMS'),
                          onPressed: () => _launchParentChannel('sms'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Call Response', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedOutcome,
                      items: const [
                        DropdownMenuItem(value: 'Connected', child: Text('Connected')),
                        DropdownMenuItem(value: 'No Answer', child: Text('No Answer')),
                        DropdownMenuItem(value: 'Busy', child: Text('Busy')),
                        DropdownMenuItem(value: 'Wrong Number', child: Text('Wrong Number')),
                        DropdownMenuItem(value: 'Call Failed', child: Text('Call Failed')),
                      ],
                      onChanged: (value) => setState(() {
                        if (value != null) _selectedOutcome = value;
                      }),
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Call Outcome'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      maxLines: 3,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Parent Response / Notes'),
                      onChanged: (value) => setState(() => _responseNotes = value),
                      initialValue: _responseNotes,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Follow-up Required'),
                      value: _followUpRequired,
                      onChanged: (value) => setState(() => _followUpRequired = value),
                    ),
                    if (_followUpRequired) ...[
                      TextFormField(
                        maxLines: 2,
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Follow-up Notes'),
                        onChanged: (value) => setState(() => _followUpNotes = value),
                        initialValue: _followUpNotes,
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _selectFollowUpDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Follow-up Date'),
                          child: Text(_followUpDate != null ? DateTimeUtils.formatDate(_followUpDate!) : 'Select date'),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 12),
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(_isRecording ? 'Recording...' : 'Voice Note', style: const TextStyle(fontWeight: FontWeight.bold))),
                                ElevatedButton.icon(
                                  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                                  label: Text(_isRecording ? 'Stop' : 'Record'),
                                  onPressed: _toggleRecording,
                                ),
                              ],
                            ),
                            if (_voiceNotePath != null) ...[
                              const SizedBox(height: 8),
                              Text('Saved: ${_voiceNotePath!.split(Platform.pathSeparator).last}'),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _saving ? null : _saveCallLog,
                      child: _saving ? const CircularProgressIndicator() : const Text('Save Call Details'),
                    ),
                    const SizedBox(height: 24),
                    const Text('Call History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(height: 260, child: _buildCallHistory()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
