import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'clients.dart';
import 'common.dart';
import 'directory.dart';
import 'listings.dart';
import 'network.dart';
import 'strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: brandDeep,
    statusBarIconBrightness: Brightness.light,
  ));
  final prefs = await SharedPreferences.getInstance();
  appLang.value = prefs.getString('lang') ?? 'hi';
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const PropDealApp());
}

class PropDealApp extends StatelessWidget {
  const PropDealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (_, __, ___) => MaterialApp(
        title: 'PropDeal',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _notDealer = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    db.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.signedOut ||
          data.event == AuthChangeEvent.initialSession) {
        _loadDealer();
      }
    });
  }

  Future<void> _loadDealer() async {
    if (db.auth.currentSession == null) {
      me.value = null;
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() { _loading = true; _error = false; _notDealer = false; });
    try {
      final row = await db.from('pd_dealers').select().eq('id', myId).maybeSingle();
      me.value = row;
      if (mounted) setState(() { _loading = false; _notDealer = row == null; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (db.auth.currentSession == null) return const AuthScreen();
    if (_error) {
      return Scaffold(body: SafeArea(child: ErrorRetry(onRetry: _loadDealer)));
    }
    if (_notDealer || me.value == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr('notDealer'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => db.auth.signOut(), child: Text(tr('logout'))),
              ],
            ),
          ),
        ),
      );
    }
    return const HomeShell();
  }
}

// ───────────────────────── Login / Signup ─────────────────────────

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _signup = false;
  bool _busy = false;
  String? _error;
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _firm = TextEditingController();
  final _city = TextEditingController();

  String _email(String phone) => '${digits10(phone)}@phone.propdeal.app';

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (_signup) {
        try {
          await db.functions.invoke('pd-signup', body: {
            'phone': digits10(_phone.text),
            'password': _pass.text,
            'name': _name.text.trim(),
            'firm': _firm.text.trim(),
            'city': _city.text.trim(),
          });
        } on FunctionException catch (e) {
          setState(() { _busy = false; _error = e.status == 409 ? tr('errExists') : tr('errNet'); });
          return;
        }
      }
      await db.auth.signInWithPassword(email: _email(_phone.text), password: _pass.text);
    } on AuthException catch (_) {
      setState(() { _busy = false; _error = tr('errLogin'); });
      return;
    } catch (_) {
      setState(() { _busy = false; _error = tr('errNet'); });
      return;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _toggleLang(),
                  child: Text(appLang.value == 'hi' ? 'Hinglish' : 'हिंदी'),
                ),
              ),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset('assets/logo.png', width: 110, height: 110),
                ),
              ),
              const SizedBox(height: 12),
              Text(tr('tagline'), textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(tr('login'))),
                  ButtonSegment(value: true, label: Text(tr('signup'))),
                ],
                selected: {_signup},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() { _signup = s.first; _error = null; }),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: tr('mobile'), prefixText: '+91 '),
                validator: (v) => isMobile(v) ? null : tr('errPhone'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pass,
                obscureText: true,
                decoration: InputDecoration(labelText: tr('password')),
                validator: (v) => (v ?? '').length >= 6 ? null : tr('errPassword'),
              ),
              if (_signup) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: tr('name')),
                  validator: (v) => (v ?? '').trim().isEmpty ? tr('errRequired') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _firm,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: tr('firm')),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: tr('city')),
                  validator: (v) => (v ?? '').trim().isEmpty ? tr('errRequired') : null,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: badRed, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(_signup ? tr('signupBtn') : tr('loginBtn')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _toggleLang() async {
  appLang.value = appLang.value == 'hi' ? 'en' : 'hi';
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('lang', appLang.value);
}

// ───────────────────────── Main tabs ─────────────────────────

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final titles = [tr('tabMine'), tr('tabNetwork'), tr('tabClients'), tr('tabDirectory')];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/logo.png', width: 32, height: 32),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(titles[_tab], style: const TextStyle(fontWeight: FontWeight.w800))),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr('profile'),
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [MyListingsTab(), NetworkTab(), ClientsTab(), DirectoryTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        indicatorColor: softOrange,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_work_outlined),
              selectedIcon: const Icon(Icons.home_work, color: brandDeep), label: tr('tabMine')),
          NavigationDestination(icon: const Icon(Icons.travel_explore_outlined),
              selectedIcon: const Icon(Icons.travel_explore, color: brandDeep), label: tr('tabNetwork')),
          NavigationDestination(icon: const Icon(Icons.people_outline),
              selectedIcon: const Icon(Icons.people, color: brandDeep), label: tr('tabClients')),
          NavigationDestination(icon: const Icon(Icons.contact_phone_outlined),
              selectedIcon: const Icon(Icons.contact_phone, color: brandDeep), label: tr('tabDirectory')),
        ],
      ),
    );
  }
}

// ───────────────────────── Profile ─────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _name = TextEditingController(text: me.value?['name'] ?? '');
  late final _firm = TextEditingController(text: me.value?['firm'] ?? '');
  late final _city = TextEditingController(text: me.value?['city'] ?? '');
  bool _busy = false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _city.text.trim().isEmpty) {
      showMsg(context, tr('errRequired'));
      return;
    }
    setState(() => _busy = true);
    try {
      final row = await db.from('pd_dealers').update({
        'name': _name.text.trim(),
        'firm': _firm.text.trim().isEmpty ? null : _firm.text.trim(),
        'city': _city.text.trim(),
      }).eq('id', myId).select().single();
      me.value = row;
      if (mounted) showMsg(context, tr('saved'));
    } catch (_) {
      if (mounted) showMsg(context, tr('errNet'));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('myAccount'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(phoneLabel(me.value?['phone']),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: InputDecoration(labelText: tr('name'))),
          const SizedBox(height: 12),
          TextField(controller: _firm, decoration: InputDecoration(labelText: tr('firm'))),
          const SizedBox(height: 12),
          TextField(controller: _city, decoration: InputDecoration(labelText: tr('city'))),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? tr('saving') : tr('save'))),
          const SizedBox(height: 28),
          Text(tr('language'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ChoiceRow(
            values: const ['hi', 'en'],
            selected: appLang.value,
            labelOf: (v) => v == 'hi' ? 'हिंदी' : 'Hinglish',
            onSelected: (v) async {
              if (v != appLang.value) await _toggleLang();
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: Text(tr('logout')),
            onPressed: () async {
              await db.auth.signOut();
              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
        ],
      ),
    );
  }
}
