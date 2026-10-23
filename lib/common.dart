import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'strings.dart';

const supabaseUrl = 'https://toouzmbhlltipjjcyqim.supabase.co';
const supabaseKey = 'sb_publishable_zukyv1ySo8aD78ACjyCxnA_axXqLSxs';
const photoBucket = 'pd-photos';

SupabaseClient get db => Supabase.instance.client;
String get myId => db.auth.currentUser!.id;

/// Logged-in dealer's row from pd_dealers.
final ValueNotifier<Map<String, dynamic>?> me = ValueNotifier(null);

// Brand colours (from the PropDeal icon)
const brandOrange = Color(0xFFF26A0F);
const brandDeep = Color(0xFFC9420A);
const brandYellow = Color(0xFFF5B800);
const pageBg = Color(0xFFFFF8F2);
const ink = Color(0xFF23150D);
const muted = Color(0xFF6B5244);
const line = Color(0xFFF0DCCB);
const softOrange = Color(0xFFFFE6D2);
const goodGreen = Color(0xFF1E7A3C);
const badRed = Color(0xFFB3261E);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: brandOrange).copyWith(
    primary: brandDeep,
    onPrimary: Colors.white,
    secondary: brandYellow,
    surface: Colors.white,
    onSurface: ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: pageBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: brandDeep,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: line),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

String digits10(String? phone) {
  final d = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  return d.length >= 10 ? d.substring(d.length - 10) : d;
}

bool isMobile(String? phone) => RegExp(r'^[6-9]\d{9}$').hasMatch(digits10(phone));

String phoneLabel(String? phone) {
  final d = digits10(phone);
  if (d.length != 10) return phone ?? '';
  return '+91 ${d.substring(0, 5)} ${d.substring(5)}';
}

String _trim(double v) {
  final s = v.toStringAsFixed(2);
  return s.replaceAll(RegExp(r'\.?0+$'), '');
}

String groupIndian(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

String formatPrice(num? price, String? purpose) {
  if (price == null) return '';
  final p = price.toInt();
  String s;
  if (p >= 10000000) {
    s = '₹ ${_trim(p / 10000000)} ${tr('crore')}';
  } else if (p >= 100000) {
    s = '₹ ${_trim(p / 100000)} ${tr('lakh')}';
  } else {
    s = '₹ ${groupIndian(p)}';
  }
  return purpose == 'rent' ? '$s${tr('perMonth')}' : s;
}

String photoUrl(String path) => db.storage.from(photoBucket).getPublicUrl(path);

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

Future<void> callNumber(BuildContext context, String? phone) async {
  final d = digits10(phone);
  if (d.isEmpty) return;
  final ok = await launchUrl(Uri.parse('tel:+91$d'), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showMsg(context, tr('errNet'));
}

Future<void> openWhatsApp(BuildContext context, String? phone, String text) async {
  final d = digits10(phone);
  if (d.isEmpty) return;
  final uri = Uri.parse('https://wa.me/91$d?text=${Uri.encodeComponent(text)}');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showMsg(context, tr('errNet'));
}

Future<void> shareOnWhatsApp(BuildContext context, String text) async {
  final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showMsg(context, tr('errNet'));
}

void showMsg(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> confirmDelete(BuildContext context) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(tr('confirmDelete')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('cancel'))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: badRed, minimumSize: const Size(48, 44)),
          onPressed: () => Navigator.pop(c, true),
          child: Text(tr('delete')),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Row of choice chips; [labels] maps value -> label key.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.values,
    required this.selected,
    required this.onSelected,
    this.labelOf,
    this.scroll = false,
  });

  final List<String> values;
  final String? selected;
  final ValueChanged<String> onSelected;
  final String Function(String)? labelOf;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final v in values)
        ChoiceChip(
          label: Text(labelOf != null ? labelOf!(v) : tr(v)),
          selected: v == selected,
          onSelected: (_) => onSelected(v),
          selectedColor: brandDeep,
          labelStyle: TextStyle(
            color: v == selected ? Colors.white : ink,
            fontWeight: FontWeight.w600,
          ),
          checkmarkColor: Colors.white,
          backgroundColor: Colors.white,
          side: BorderSide(color: v == selected ? brandDeep : line),
        ),
    ];
    if (scroll) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (final c in chips) Padding(padding: const EdgeInsets.only(right: 8), child: c),
          ],
        ),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.bg = softOrange, this.fg = brandDeep});
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

Pill statusPill(String status) {
  switch (status) {
    case 'sold':
      return Pill(tr('sold'), bg: const Color(0xFFE1F2E6), fg: goodGreen);
    case 'hidden':
      return Pill(tr('hidden'), bg: const Color(0xFFEDE7E3), fg: muted);
    default:
      return Pill(tr('active'));
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key, this.icon = Icons.home_work_outlined});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(icon, size: 56, color: brandOrange),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: muted)),
      ],
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.wifi_off, size: 48, color: muted),
        const SizedBox(height: 12),
        Text(tr('errNet'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 16),
        Center(child: OutlinedButton(onPressed: onRetry, child: Text(tr('retry')))),
      ],
    );
  }
}

/// Property card used in Meri Listing, Network and matches.
class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.l, required this.onTap, this.showDealer = false});
  final Map<String, dynamic> l;
  final VoidCallback onTap;
  final bool showDealer;

  @override
  Widget build(BuildContext context) {
    final photos = List<String>.from(l['photos'] ?? const []);
    final dealer = l['pd_dealers'] as Map<String, dynamic>?;
    final place = [l['locality'], l['city']].where((e) => (e ?? '').toString().isNotEmpty).join(', ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              height: 120,
              child: photos.isEmpty
                  ? Container(
                      color: softOrange,
                      child: const Icon(Icons.home_work_outlined, color: brandOrange, size: 36),
                    )
                  : Image.network(
                      photoUrl(photos.first),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: softOrange,
                        child: const Icon(Icons.broken_image_outlined, color: brandOrange),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatPrice(l['price'] as num?, l['purpose'] as String?),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l['title'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(place, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Pill(tr(l['purpose'] ?? 'sale'), bg: const Color(0xFFFFF3C4), fg: const Color(0xFF7A5600)),
                        Pill(tr(l['ptype'] ?? 'other')),
                        if (!showDealer) statusPill(l['status'] ?? 'active'),
                      ],
                    ),
                    if (showDealer && dealer != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${tr('dealer')}: ${dealer['firm'] ?? dealer['name']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: muted, fontWeight: FontWeight.w600),
                      ),
                    ],
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

/// Text for sharing a listing on WhatsApp.
String listingShareText(Map<String, dynamic> l, Map<String, dynamic>? dealer) {
  final b = StringBuffer();
  b.writeln('🏠 *${l['title']}*');
  b.writeln(formatPrice(l['price'] as num?, l['purpose'] as String?));
  b.writeln('${tr(l['ptype'] ?? 'other')} • ${tr(l['purpose'] ?? 'sale')}');
  if (l['area'] != null) b.writeln('${tr('area')}: ${l['area']} ${tr(l['area_unit'] ?? 'sqft')}');
  if (l['bedrooms'] != null) b.writeln('${l['bedrooms']} BHK');
  final place = [l['locality'], l['city']].where((e) => (e ?? '').toString().isNotEmpty).join(', ');
  if (place.isNotEmpty) b.writeln('📍 $place');
  if ((l['description'] ?? '').toString().isNotEmpty) b.writeln('\n${l['description']}');
  final photos = List<String>.from(l['photos'] ?? const []);
  if (photos.isNotEmpty) {
    b.writeln('\n${tr('photos')}:');
    for (final p in photos.take(4)) {
      b.writeln(photoUrl(p));
    }
  }
  if (dealer != null) {
    b.writeln('\n${tr('contactFor')}: ${dealer['firm'] ?? dealer['name']} – ${phoneLabel(dealer['phone'])}');
  }
  b.write('\nPropDeal');
  return b.toString();
}
