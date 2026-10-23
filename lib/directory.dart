import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'common.dart';
import 'strings.dart';

const _cityHi = {
  'Saharanpur': 'सहारनपुर', 'Karnal': 'करनाल', 'Yamunanagar': 'यमुनानगर', 'Dehradun': 'देहरादून',
  'Haridwar': 'हरिद्वार', 'Roorkee': 'रुड़की', 'Rishikesh': 'ऋषिकेश', 'Panipat': 'पानीपत',
  'Ambala': 'अंबाला', 'Jagadhri': 'जगाधरी',
};
const _dirStatuses = {
  'called': 'dCalled', 'interested': 'dInterested', 'joined': 'dJoined', 'no': 'dNo', 'dead': 'dDead',
};

String _city(String c) => appLang.value == 'hi' ? (_cityHi[c] ?? c) : c;

/// Google Maps dealers & builders, for building a network (side feature).
class DirectoryTab extends StatefulWidget {
  const DirectoryTab({super.key});

  @override
  State<DirectoryTab> createState() => _DirectoryTabState();
}

class _DirectoryTabState extends State<DirectoryTab> {
  List<Map<String, dynamic>> _all = [];
  Map<String, String> _status = {};
  String _cityF = 'all';
  String _q = '';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final raw = await rootBundle.loadString('assets/contacts.json');
    final list = List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('dir_status');
    if (!mounted) return;
    setState(() {
      _all = list.where((d) => d['p'] != null).toList();
      if (s != null) _status = Map<String, String>.from(jsonDecode(s) as Map);
      _ready = true;
    });
  }

  Future<void> _setStatus(String id, String? v) async {
    setState(() {
      if (v == null) {
        _status.remove(id);
      } else {
        _status[id] = v;
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dir_status', jsonEncode(_status));
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Center(child: CircularProgressIndicator());
    final cities = <String>[];
    for (final d in _all) {
      if (!cities.contains(d['c'])) cities.add(d['c'] as String);
    }
    final q = _q.toLowerCase();
    final rows = _all.where((d) {
      if (_cityF != 'all' && d['c'] != _cityF) return false;
      if (q.isNotEmpty && !'${d['n']} ${d['a']} ${d['c']}'.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
    final joined = _status.values.where((v) => v == 'joined').length;
    final talked = _status.values.where((v) => v != 'dead').length;
    final myName = me.value?['firm'] ?? me.value?['name'] ?? '';

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(tr('dirNote'), style: const TextStyle(color: muted)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            Pill('${tr('dCalled')}: $talked'),
            const SizedBox(width: 8),
            Pill('${tr('dJoined')}: $joined', bg: const Color(0xFFE1F2E6), fg: goodGreen),
          ]),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(hintText: tr('search'), prefixIcon: const Icon(Icons.search), isDense: true),
            onChanged: (v) => setState(() => _q = v.trim()),
          ),
        ),
        const SizedBox(height: 10),
        ChoiceRow(
          scroll: true,
          values: ['all', ...cities],
          selected: _cityF,
          labelOf: (v) => v == 'all' ? tr('all') : _city(v),
          onSelected: (v) => setState(() => _cityF = v),
        ),
        const SizedBox(height: 12),
        for (final d in rows)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(d['n'] ?? '',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                        Pill(d['ty'] == 'Dealer' ? tr('dealer') : 'Builder'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        _city(d['c'] as String),
                        if ((d['a'] ?? '').toString().isNotEmpty) d['a'],
                      ].join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                    if (d['r'] != null)
                      Text('★ ${d['r']} (${d['v'] ?? 0})',
                          style: const TextStyle(color: Color(0xFF9A6A00), fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    SelectableText(d['p'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.call),
                            label: Text(tr('call')),
                            onPressed: () => callNumber(context, d['p']),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: d['w'] == true
                              ? FilledButton.tonalIcon(
                                  style: FilledButton.styleFrom(minimumSize: const Size(48, 50)),
                                  icon: const Icon(Icons.chat_outlined),
                                  label: Text(tr('whatsapp')),
                                  onPressed: () {
                                    final short = (d['n'] as String).split('|').first.split(' - ').first.trim();
                                    openWhatsApp(context, d['p'],
                                        tr('waIntro').replaceAll('{name}', short).replaceAll('{me}', myName));
                                  },
                                )
                              : Center(child: Text(tr('landline'), style: const TextStyle(color: muted))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in _dirStatuses.entries)
                          ChoiceChip(
                            label: Text(tr(e.value), style: const TextStyle(fontSize: 12)),
                            selected: _status['${d['id']}'] == e.key,
                            visualDensity: VisualDensity.compact,
                            selectedColor: softOrange,
                            onSelected: (sel) => _setStatus('${d['id']}', sel ? e.key : null),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
