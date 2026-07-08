import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dose_wise/src/core/providers/app_data_provider.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/core/utils/formatters.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/medication_colors.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/medications/widgets/form_fields.dart';
import 'package:dose_wise/src/features/medications/widgets/schedule_editor.dart';
import 'package:dose_wise/src/features/medications/widgets/supply_fields.dart';
import 'package:dose_wise/src/features/profiles/providers/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Add (null id) or edit (existing id) a medication.
final class MedicationFormScreen extends ConsumerStatefulWidget {
  const MedicationFormScreen({this.medicationId, super.key});

  final String? medicationId;

  @override
  ConsumerState<MedicationFormScreen> createState() =>
      _MedicationFormScreenState();
}

final class _MedicationFormScreenState
    extends ConsumerState<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();
  final _stockController = TextEditingController();
  final _thresholdController = TextEditingController(
    text: '${Medication.defaultLowStockThreshold}',
  );

  Medication? _existing;
  MedicationForm _form = MedicationForm.tablet;
  int _colorValue = MedicationColors.defaultColor;
  late DateTime _startDate;
  DateTime? _endDate;
  ScheduleType _scheduleType = ScheduleType.weekly;
  List<DoseTime> _times = const [DoseTime(hour: 8, minute: 0)];
  Set<int> _weekdays = const {1, 2, 3, 4, 5, 6, 7};
  int _intervalDays = 2;
  String? _scheduleError;
  bool _trackSupply = false;
  bool _remindersEnabled = true;

  @override
  void initState() {
    super.initState();
    _startDate = ref.read(clockProvider)();
    final id = widget.medicationId;
    if (id == null) return;
    final medications =
        ref.read(appDataProvider).valueOrNull?.medications ?? const [];
    Medication? existing;
    for (final medication in medications) {
      if (medication.id == id) existing = medication;
    }
    if (existing == null) return;
    _existing = existing;
    _nameController.text = existing.name;
    _dosageController.text = existing.dosage;
    _notesController.text = existing.notes;
    _form = existing.form;
    _colorValue = existing.colorValue;
    _startDate = existing.startDate;
    _endDate = existing.endDate;
    _scheduleType = existing.schedule.type;
    if (existing.schedule.times.isNotEmpty) {
      _times = existing.schedule.sortedTimes;
    }
    if (existing.schedule.weekdays.isNotEmpty) {
      _weekdays = existing.schedule.weekdays;
    }
    if (existing.schedule.type == ScheduleType.interval) {
      _intervalDays = existing.schedule.intervalDays;
    }
    _trackSupply = existing.tracksStock;
    if (existing.currentStock != null) {
      _stockController.text = '${existing.currentStock}';
    }
    _thresholdController.text = '${existing.lowStockThreshold}';
    _remindersEnabled = existing.remindersEnabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Schedule? _buildSchedule() {
    switch (_scheduleType) {
      case ScheduleType.weekly:
        if (_weekdays.isEmpty) return _fail('Select at least one weekday.');
        if (_times.isEmpty) return _fail('Add at least one time of day.');
        return Schedule.weekly(times: _times, weekdays: _weekdays);
      case ScheduleType.interval:
        if (_times.isEmpty) return _fail('Add at least one time of day.');
        return Schedule.interval(times: _times, everyDays: _intervalDays);
      case ScheduleType.asNeeded:
        return const Schedule.asNeeded();
    }
  }

  Schedule? _fail(String message) {
    setState(() => _scheduleError = message);
    return null;
  }

  Future<void> _save() async {
    setState(() => _scheduleError = null);
    final formValid = _formKey.currentState!.validate();
    final schedule = _buildSchedule();
    if (!formValid || schedule == null) return;

    final medication = Medication(
      id: _existing?.id ?? ref.read(uuidProvider).v4(),
      // New medications belong to the profile being viewed; edits never
      // move a medication between profiles.
      profileId: _existing?.profileId ?? ref.read(activeProfileProvider).id,
      name: _nameController.text.trim(),
      dosage: _dosageController.text.trim(),
      form: _form,
      colorValue: _colorValue,
      notes: _notesController.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      schedule: schedule,
      currentStock:
          _trackSupply ? int.tryParse(_stockController.text.trim()) ?? 0 : null,
      lowStockThreshold: int.tryParse(_thresholdController.text.trim()) ??
          Medication.defaultLowStockThreshold,
      remindersEnabled: _remindersEnabled,
      archived: _existing?.archived ?? false,
    );
    await ref.read(appDataProvider.notifier).upsertMedication(medication);
    if (mounted) await Navigator.of(context).maybePop();
  }

  Future<void> _delete() async {
    final existing = _existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${existing.name}?'),
        content: const Text(
          'This removes the medication and its dose history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(appDataProvider.notifier).deleteMedication(existing.id);
    if (mounted) await Navigator.of(context).maybePop();
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isEnd ? (_endDate ?? _startDate) : _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => isEnd ? _endDate = picked : _startDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit medication' : 'Add medication'),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            LabeledField(
              label: 'Name',
              child: TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'e.g. Amoxicillin'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
            ),
            LabeledField(
              label: 'Dosage',
              child: TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(hintText: 'e.g. 500 mg'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Dosage is required'
                    : null,
              ),
            ),
            LabeledField(
              label: 'Form',
              child: DropdownButtonFormField<MedicationForm>(
                initialValue: _form,
                items: [
                  for (final form in MedicationForm.values)
                    DropdownMenuItem(value: form, child: Text(form.label)),
                ],
                onChanged: (form) =>
                    setState(() => _form = form ?? MedicationForm.tablet),
              ),
            ),
            LabeledField(
              label: 'Color tag',
              child: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final color in MedicationColors.palette)
                    GestureDetector(
                      onTap: () => setState(() => _colorValue = color),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(color),
                        child: _colorValue == color
                            ? const Icon(Icons.check,
                                size: 18, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: DateButton(
                    label: 'Starts',
                    value: formatDate(_startDate),
                    onTap: () => _pickDate(isEnd: false),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: DateButton(
                    label: 'Ends (optional)',
                    value: _endDate == null
                        ? 'No end date'
                        : formatDate(_endDate!),
                    onTap: () => _pickDate(isEnd: true),
                    onClear: _endDate == null
                        ? null
                        : () => setState(() => _endDate = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ScheduleEditor(
              type: _scheduleType,
              times: _times,
              weekdays: _weekdays,
              intervalDays: _intervalDays,
              errorText: _scheduleError,
              onTypeChanged: (type) => setState(() => _scheduleType = type),
              onTimesChanged: (times) => setState(() => _times = times),
              onWeekdaysChanged: (days) => setState(() => _weekdays = days),
              onIntervalChanged: (days) => setState(() => _intervalDays = days),
            ),
            const SizedBox(height: AppSpacing.lg),
            SupplyAndReminderFields(
              trackSupply: _trackSupply,
              onTrackSupplyChanged: (value) =>
                  setState(() => _trackSupply = value),
              stockController: _stockController,
              thresholdController: _thresholdController,
              remindersEnabled: _remindersEnabled,
              onRemindersChanged: (value) =>
                  setState(() => _remindersEnabled = value),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: 'Notes',
              child: TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g. Take with food',
                ),
              ),
            ),
            VaultButton(label: 'Save medication', onPressed: _save),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
