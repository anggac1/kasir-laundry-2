/// Utilitas format angka dan tanggal.
/// Sengaja ditulis manual (tanpa paket intl) supaya dependensi build minimal.

String rupiah(num value) {
  final n = value.round();
  final neg = n < 0;
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${neg ? '-' : ''}Rp$buf';
}

/// Angka tanpa prefix Rp, untuk dipakai di struk bila diinginkan.
String angka(num value) => rupiah(value).replaceFirst('Rp', '');

String _2(int v) => v.toString().padLeft(2, '0');

/// Tanggal memakai jam perangkat (DateTime.now()), sesuai permintaan.
String tanggal(DateTime d) => '${_2(d.day)}/${_2(d.month)}/${d.year}';

String jam(DateTime d) => '${_2(d.hour)}:${_2(d.minute)}';

String tanggalJam(DateTime d) => '${tanggal(d)} ${jam(d)}';

const _namaHari = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

String hari(DateTime d) => _namaHari[(d.weekday - 1) % 7];

/// Tampilkan qty tanpa desimal bila bulat: 3 kg, bukan 3.0 kg.
String qtyStr(double q) {
  if (q == q.roundToDouble()) return q.round().toString();
  return q.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

DateTime? msToDate(int? ms) =>
    ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
