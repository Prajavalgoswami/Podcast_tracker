import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import 'edit_profile_screen.dart';
import '../../core/services/local_storage_service.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = auth.userProfile;
    final colorScheme = Theme.of(context).colorScheme;

    // Derive dynamic stats (no fake defaults for new users)
    final String userId = auth.user?.uid ?? '';
    final storage = LocalStorageService();
    final favoritesCount = userId.isEmpty ? 0 : storage.getUserFavorites(userId).length;
    // Removed Total Listened and Following tiles

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundImage: (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                          ? NetworkImage(user.photoUrl!)
                          : null,
                      child: (user?.photoUrl == null || user!.photoUrl!.isEmpty)
                          ? Text(
                              (user?.displayName.isNotEmpty == true ? user!.displayName[0] : 'U').toUpperCase(),
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Material(
                        color: colorScheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.edit, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    Text(
                      user?.displayName.isNotEmpty == true ? user!.displayName : 'User',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'email@example.com',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _StatCard(label: 'Favorites', value: favoritesCount.toString(), icon: Icons.favorite),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Account Settings',
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Edit Profile'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'App Settings',
                children: [
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.brightness_6_outlined),
                    title: const Text('Theme'),
                    subtitle: Text(themeProvider.themeModeString.toUpperCase()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final mode = await showModalBottomSheet<ThemeMode>(
                        context: context,
                        showDragHandle: true,
                        builder: (context) => _ThemeSheet(current: themeProvider.themeMode),
                      );
                      if (mode != null) {
                        await themeProvider.setThemeMode(mode);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _SectionCard(
                title: 'About',
                children: [
                  ListTile(
                    leading: Icon(Icons.privacy_tip_outlined),
                    title: Text('Privacy Policy'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.description_outlined),
                    title: Text('Terms & Conditions'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('About App'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await context.read<AuthProvider>().signOut();
                      if (context.mounted) {
                        // Use rootNavigator to ensure we navigate from the root
                        // Clear all routes and navigate to login screen
                        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primary.withOpacity(0.12),
              child: Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const Divider(height: 1),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ThemeSheet extends StatelessWidget {
  final ThemeMode current;
  const _ThemeSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    Widget buildTile(ThemeMode mode, String title, IconData icon) {
      final selected = current == mode;
      return ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: selected ? const Icon(Icons.check) : null,
        onTap: () => Navigator.pop(context, mode),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const Text('Choose Theme', style: TextStyle(fontWeight: FontWeight.w700)),
          buildTile(ThemeMode.system, 'System', Icons.smartphone),
          buildTile(ThemeMode.light, 'Light', Icons.wb_sunny_outlined),
          buildTile(ThemeMode.dark, 'Dark', Icons.nightlight_round),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _LanguageSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    final langs = themeProvider.availableLanguages;
    final current = themeProvider.selectedLanguage;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const Text('Choose Language', style: TextStyle(fontWeight: FontWeight.w700)),
          ...langs.map((lang) {
            final selected = lang['code'] == current;
            return ListTile(
              leading: const Icon(Icons.language),
              title: Text(lang['name']!),
              trailing: selected ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, lang['code']),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}


