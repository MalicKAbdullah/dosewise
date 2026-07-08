import 'dart:convert';
import 'dart:typed_data';

import 'package:dose_wise/src/features/dose_log/models/dose_record.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/stats/services/pdf/adherence_report_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pdf_test_fonts.dart';

void main() {
  final now = DateTime(2026, 7, 3, 12);

  Medication med({
    String id = 'm1',
    String name = 'Metformin',
    List<DoseTime> times = const [
      DoseTime(hour: 8, minute: 0),
      DoseTime(hour: 20, minute: 0),
    ],
  }) =>
      Medication(
        id: id,
        name: name,
        dosage: '500 mg',
        form: MedicationForm.tablet,
        colorValue: 0xFF14B8A6,
        startDate: DateTime(2026, 1, 1),
        schedule: Schedule.weekly(
          times: times,
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
        ),
      );

  List<DoseRecord> recordsFor(
    Medication medication, {
    required int days,
    required DateTime now,
  }) {
    final records = <DoseRecord>[];
    for (var i = 0; i < days; i++) {
      final day = DateTime(now.year, now.month, now.day - i);
      for (final time in medication.schedule.times) {
        final scheduled = time.onDay(day);
        if (scheduled.isAfter(now)) continue;
        records.add(
          DoseRecord(
            id: '${medication.id}-$i-${time.hour}',
            medicationId: medication.id,
            scheduledTime: scheduled,
            outcome: i.isEven ? DoseOutcome.taken : DoseOutcome.skipped,
            recordedAt: scheduled.add(const Duration(minutes: 3)),
          ),
        );
      }
    }
    return records;
  }

  void expectPdfMagic(Uint8List bytes) {
    expect(bytes, isNotEmpty);
    expect(bytes.sublist(0, 5), [0x25, 0x50, 0x44, 0x46, 0x2D]); // %PDF-
    expect(bytes.length, greaterThan(1000));
  }

  int pageCount(Uint8List bytes) =>
      RegExp('/Type */Page[^s]').allMatches(latin1.decode(bytes)).length;

  test('renders valid PDF bytes for sample data (30 days)', () async {
    final medication = med();
    final bytes = await AdherenceReportPdfService.render(
      AdherencePdfRequest(
        medications: [medication],
        records: recordsFor(medication, days: 10, now: now),
        now: now,
        days: 30,
        fonts: loadTestFonts(),
        patientName: 'Me',
      ),
    );
    expectPdfMagic(bytes);
  });

  test('unicode medication and patient names render', () async {
    final medication = med(name: 'Insülin naïve « Ω » (dépôt)');
    final bytes = await AdherenceReportPdfService.render(
      AdherencePdfRequest(
        medications: [medication],
        records: recordsFor(medication, days: 5, now: now),
        now: now,
        days: 30,
        fonts: loadTestFonts(),
        patientName: 'Žofia Müllerová',
      ),
    );
    expectPdfMagic(bytes);
  });

  test('a 90-day log appendix spills onto multiple pages', () async {
    final medications = [
      med(),
      med(id: 'm2', name: 'Lisinopril'),
      med(id: 'm3', name: 'Atorvastatin'),
    ];
    final records = [
      for (final m in medications) ...recordsFor(m, days: 90, now: now),
    ];
    final bytes = await AdherenceReportPdfService.render(
      AdherencePdfRequest(
        medications: medications,
        records: records,
        now: now,
        days: 90,
        fonts: loadTestFonts(),
      ),
    );
    expectPdfMagic(bytes);
    expect(pageCount(bytes), greaterThan(2));
  });

  test('renders with no data at all (empty sections)', () async {
    final bytes = await AdherenceReportPdfService.render(
      AdherencePdfRequest(
        medications: const [],
        records: const [],
        now: now,
        days: 30,
        fonts: loadTestFonts(),
      ),
    );
    expectPdfMagic(bytes);
    expect(pageCount(bytes), 1);
  });
}
