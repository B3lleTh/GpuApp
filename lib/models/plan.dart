import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class Plan {
  final String id;
  final int hours, studyMin, breakMin, totalBlocks, completedBlocks;
  final String method;

  bool   get isDone         => completedBlocks >= totalBlocks;
  double get progress       => totalBlocks == 0 ? 0 : completedBlocks / totalBlocks;
  int    get totalStudyMins => studyMin * totalBlocks;

  const Plan({
    required this.id, required this.hours, required this.method,
    required this.studyMin, required this.breakMin,
    required this.totalBlocks, required this.completedBlocks,
  });

  factory Plan.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return Plan(
      id:              d.id,
      hours:           (m['hours']           as num?)?.toInt() ?? 0,
      method:          (m['method']          as String?) ?? '—',
      studyMin:        (m['studyMin']        as num?)?.toInt() ?? 25,
      breakMin:        (m['breakMin']        as num?)?.toInt() ?? 5,
      totalBlocks:     (m['totalBlocks']     as num?)?.toInt() ?? 1,
      completedBlocks: (m['completedBlocks'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap(String uid) => {
    'uid': uid, 'hours': hours, 'method': method,
    'studyMin': studyMin, 'breakMin': breakMin,
    'totalBlocks': totalBlocks, 'completedBlocks': completedBlocks,
    'createdAt': DateTime.now().millisecondsSinceEpoch,
  };
}

Plan buildPlan(int hours) {
  final String method; final int sm, bm;
  if (hours <= 2)      { method = 'Pomodoro';  sm = 25; bm = 5;  }
  else if (hours <= 5) { method = '52 / 17';   sm = 52; bm = 17; }
  else                 { method = 'Deep Work'; sm = 90; bm = 15; }
  return Plan(
    id: '', hours: hours, method: method, studyMin: sm, breakMin: bm,
    totalBlocks: max((hours * 60) ~/ (sm + bm), 1), completedBlocks: 0,
  );
}