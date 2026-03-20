import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/theme.dart';
import '../models/plan.dart';
import 'shared.dart';

enum PlanPhase { idle, study, rest, paused, done }

class PlanCard extends StatefulWidget {
  final Plan plan;
  const PlanCard({super.key, required this.plan});
  @override State<PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<PlanCard> {
  PlanPhase _phase     = PlanPhase.idle;
  PlanPhase _prePause  = PlanPhase.study; // fase antes de pausar
  int       _secs      = 0;
  Timer?    _timer;

  Plan get p => widget.plan;

  @override void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  void didUpdateWidget(PlanCard old) {
    super.didUpdateWidget(old);
    if (p.isDone && _phase != PlanPhase.done) {
      _timer?.cancel();
      setState(() { _phase = PlanPhase.done; _secs = 0; });
    }
  }

  // Inicia o reanuda desde donde se pausó
  void _start() {
    if (_phase == PlanPhase.study || _phase == PlanPhase.rest || p.isDone) return;
    if (_phase == PlanPhase.paused) {
      // Reanudar — restaura la fase anterior y los segundos guardados
      setState(() => _phase = _prePause);
    } else {
      // Inicio fresco del bloque
      setState(() { _phase = PlanPhase.study; _secs = p.studyMin * 60; });
    }
    _tick();
  }

  // Pausa — congela el tiempo sin perderlo
  void _pause() {
    _timer?.cancel();
    setState(() {
      _prePause = _phase; // guarda si estaba en focus o rest
      _phase    = PlanPhase.paused;
      // _secs NO se toca — se congela donde estaba
    });
  }

  // Reinicia el bloque actual desde cero (no borra completedBlocks)
  void _reset() {
    _timer?.cancel();
    setState(() {
      _phase = PlanPhase.idle;
      _secs  = 0;
      _prePause = PlanPhase.study;
    });
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secs > 0) { setState(() => _secs--); return; }
      if (_phase == PlanPhase.study) {
        setState(() { _phase = PlanPhase.rest; _secs = p.breakMin * 60; });
      } else {
        _timer?.cancel();
        final next = p.completedBlocks + 1;
        FirebaseFirestore.instance.collection('planes').doc(p.id)
            .update({'completedBlocks': next});
        setState(() {
          _phase = next >= p.totalBlocks ? PlanPhase.done : PlanPhase.idle;
          _secs  = 0;
        });
      }
    });
  }

  Future<void> _delete() async {
    _timer?.cancel();
    await FirebaseFirestore.instance.collection('planes').doc(p.id).delete();
  }

  @override
  Widget build(BuildContext context) {
    final fin     = p.isDone || _phase == PlanPhase.done;
    final run     = _phase == PlanPhase.study || _phase == PlanPhase.rest;
    final paused  = _phase == PlanPhase.paused;
    final m = _secs ~/ 60, s = _secs % 60;

    final Color accent = fin           ? kAccent
        : _phase == PlanPhase.study    ? kActive
        : _phase == PlanPhase.rest     ? kRest
        : paused                       ? kErr.withOpacity(0.7)
        : kDim;

    final String label = fin           ? 'Done'
        : _phase == PlanPhase.study    ? 'Focus'
        : _phase == PlanPhase.rest     ? 'Rest'
        : paused                       ? 'Paused'
        : 'Idle';

    // El ring usa los segundos congelados cuando está pausado
    final int secsForPct = paused ? _secs : _secs;
    final int totalSecs  = (_prePause == PlanPhase.study ? p.studyMin : p.breakMin) * 60;
    final pct = (run || paused)
        ? secsForPct / totalSecs
        : (fin ? 1.0 : 0.0);

    return SCard(
      radius: 14, padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Row(children: [
          Text(p.method, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kHi)),
          const SizedBox(width: 6),
          Text('· ${p.hours}h', style: const TextStyle(fontSize: 12, color: kDim)),
          const Spacer(),
          Container(width: 5, height: 5,
              decoration: BoxDecoration(shape: BoxShape.circle, color: accent)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w500)),
        ]),

        const SizedBox(height: 10),

        // Progress bar (bloques completados)
        Row(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: p.progress, minHeight: 2,
                backgroundColor: kBorder,
                valueColor: AlwaysStoppedAnimation(fin ? kAccent : kActive)))),
          const SizedBox(width: 10),
          Text('${p.completedBlocks}/${p.totalBlocks}',
              style: TextStyle(fontSize: 10, color: accent,
                  fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        ]),

        const SizedBox(height: 12),

        // Timer + actions
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [

          // Ring del bloque actual
          SizedBox(width: 42, height: 42,
            child: CircularProgressIndicator(
              value: pct, strokeWidth: 2,
              backgroundColor: kBorder,
              valueColor: AlwaysStoppedAnimation(accent))),
          const SizedBox(width: 14),

          // Tiempo y subtítulo
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              (run || paused)
                  ? '${m.toString().padLeft(2,'0')} : ${s.toString().padLeft(2,'0')}'
                  : fin ? 'Completed'
                  : 'Block ${p.completedBlocks + 1} / ${p.totalBlocks}',
              style: TextStyle(
                fontSize: (run || paused) ? 22 : 13,
                fontWeight: (run || paused) ? FontWeight.w300 : FontWeight.w500,
                color: (run || paused) ? accent : kHi,
                letterSpacing: (run || paused) ? 2 : 0)),
            if (!fin) Text(
              run
                  ? (_phase == PlanPhase.study ? '${p.studyMin}m focus' : '${p.breakMin}m rest')
                  : paused
                  ? (_prePause == PlanPhase.study ? '${p.studyMin}m focus — paused' : '${p.breakMin}m rest — paused')
                  : '${p.studyMin}m focus  ·  ${p.breakMin}m rest',
              style: const TextStyle(fontSize: 11, color: kDim)),
          ])),

          // Botones de acción
          if (!fin) ...[
            if (run) ...[
              // Corriendo: Pause
              ActBtn('Pause', kErr, _pause, icon: Icons.pause_rounded),
              const SizedBox(width: 6),
            ] else if (paused) ...[
              // Pausado: Resume + Reset
              ActBtn('Resume', kActive, _start, icon: Icons.play_arrow_rounded),
              const SizedBox(width: 6),
              ActBtn('Reset', kDim, _reset, icon: Icons.refresh_rounded),
              const SizedBox(width: 6),
            ] else ...[
              // Idle: Start o Continue
              ActBtn(p.completedBlocks == 0 ? 'Start' : 'Continue',
                  accent, _start, icon: Icons.play_arrow_rounded),
              const SizedBox(width: 6),
            ],
          ],

          DeleteBtn(onTap: _delete),
        ]),
      ]),
    );
  }
}