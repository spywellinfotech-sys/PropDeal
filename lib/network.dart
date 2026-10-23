import 'package:flutter/material.dart';

import 'common.dart';
import 'listings.dart';
import 'strings.dart';

/// Active listings posted by other PropDeal dealers.
class NetworkTab extends StatefulWidget {
  const NetworkTab({super.key});

  @override
  State<NetworkTab> createState() => _NetworkTabState();
}

class _NetworkTabState extends State<NetworkTab> {
  late Future<List<Map<String, dynamic>>> _future = _load();
  String _purpose = 'all';
  String _city = 'all';
  String _q = '';

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await db
        .from('pd_listings')
        .select('*, pd_dealers(name, firm, phone, city)')
        .eq('status', 'active')
        .neq('dealer_id', myId)
        .order('created_at', ascending: false)
        .limit(300);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return RefreshIndicator(onRefresh: _refresh, child: ErrorRetry(onRetry: _refresh));
        final all = snap.data!;
        final cities = <String>{for (final l in all) (l['city'] ?? '').toString().trim()}
          ..removeWhere((c) => c.isEmpty);
        final q = _q.toLowerCase();
        final rows = all.where((l) {
          if (_purpose != 'all' && l['purpose'] != _purpose) return false;
          if (_city != 'all' && (l['city'] ?? '').toString().trim() != _city) return false;
          if (q.isNotEmpty) {
            final d = l['pd_dealers'] as Map<String, dynamic>? ?? {};
            final hay = '${l['title']} ${l['locality']} ${l['city']} ${d['name']} ${d['firm']}'.toLowerCase();
            if (!hay.contains(q)) return false;
          }
          return true;
        }).toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: tr('search'),
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _q = v.trim()),
                ),
              ),
              const SizedBox(height: 10),
              ChoiceRow(scroll: true, values: const ['all', 'sale', 'rent'], selected: _purpose,
                  onSelected: (v) => setState(() => _purpose = v)),
              if (cities.length > 1) ...[
                const SizedBox(height: 8),
                ChoiceRow(
                  scroll: true,
                  values: ['all', ...(cities.toList()..sort())],
                  selected: _city,
                  labelOf: (v) => v == 'all' ? tr('all') : v,
                  onSelected: (v) => setState(() => _city = v),
                ),
              ],
              const SizedBox(height: 12),
              if (rows.isEmpty)
                SizedBox(height: 360, child: EmptyState(tr('noNetwork'), icon: Icons.travel_explore))
              else
                for (final l in rows)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: ListingCard(
                      l: l,
                      showDealer: true,
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => ListingDetail(listing: l))),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}
