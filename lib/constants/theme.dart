import 'package:flutter/material.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const kBg     = Color(0xFF0D0D14);
const kSurf   = Color(0xFF13131C);
const kSurf2  = Color(0xFF1A1A22);
const kBorder = Color(0xFF1E1E2C);
const kDim    = Color(0xFF50506A);
const kHi     = Color(0xFFE8E8F0);
const kAccent = Color(0xFFB07FE8);
const kActive = Color(0xFF7EB8A4);
const kRest   = Color(0xFF6B8FBA);
const kErr    = Color(0xFFB05C72);

const int kMaxPlans = 5;
const int kMaxHours = 12;
const int kCD       = 4;

ThemeData buildTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBg,
  colorScheme: const ColorScheme.dark(primary: kAccent, surface: kSurf, error: kErr),
  inputDecorationTheme: InputDecorationTheme(
    filled: true, fillColor: kBg,
    labelStyle: const TextStyle(color: kDim, fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: _ob(), enabledBorder: _ob(), focusedBorder: _ob(kAccent, 1.2),
  ),
);

OutlineInputBorder _ob([Color c = kBorder, double w = 1.0]) =>
    OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w));