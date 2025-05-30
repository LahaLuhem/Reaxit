import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reaxit/api/exceptions.dart';
import 'package:reaxit/blocs.dart';
import 'package:reaxit/models.dart';
import 'package:reaxit/ui/widgets.dart';
import 'package:reaxit/config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: ThaliaAppBar(title: const Text('SETTINGS')),
      drawer: MenuDrawer(),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          if (state.hasException) {
            return RefreshIndicator(
              onRefresh: () => BlocProvider.of<SettingsCubit>(context).load(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('THEME', style: textTheme.bodySmall),
                  const _ThemeModeCard(),
                  const SizedBox(height: 8),
                  Text('NOTIFICATIONS', style: textTheme.bodySmall),
                  Center(child: Text(state.message!)),
                  const SizedBox(height: 8),
                  Text('ABOUT', style: textTheme.bodySmall),
                  const _AboutCard(),
                  const SizedBox(height: 8),
                  const _LogOutButton(),
                ],
              ),
            );
          } else if (state.isLoading && state.categories == null) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('THEME', style: textTheme.bodySmall),
                const _ThemeModeCard(),
                const SizedBox(height: 8),
                Text('NOTIFICATIONS', style: textTheme.bodySmall),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                const SizedBox(height: 8),
                Text('ABOUT', style: textTheme.bodySmall),
                const _AboutCard(),
                const SizedBox(height: 8),
                const _LogOutButton(),
              ],
            );
          } else {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('THEME', style: textTheme.bodySmall),
                const _ThemeModeCard(),
                const SizedBox(height: 8),
                Text('NOTIFICATIONS', style: textTheme.bodySmall),
                if (!state.hasPermissions!) ...[
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.notifications_off_outlined),
                          ),
                          Expanded(
                            child: Text(
                              'Notifications are disabled. Enable '
                              'them in your device settings.',
                              style: textTheme.bodyMedium!.copyWith(
                                color: textTheme.bodySmall!.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        ListTile.divideTiles(
                          context: context,
                          tiles: [
                            for (final category in state.categories!)
                              _NotificationSettingTile(
                                category: category,
                                enabled: state.device!.receiveCategory.contains(
                                  category.key,
                                ),
                              ),
                          ],
                        ).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Text('ABOUT', style: textTheme.bodySmall),
                const _AboutCard(),
                const SizedBox(height: 8),
                const _LogOutButton(),
              ],
            );
          }
        },
      ),
    );
  }
}

class _NotificationSettingTile extends StatefulWidget {
  final PushNotificationCategory category;
  final bool enabled;

  _NotificationSettingTile({required this.category, required this.enabled})
    : super(key: ValueKey(category.key));

  @override
  __NotificationSettingTileState createState() =>
      __NotificationSettingTileState();
}

class __NotificationSettingTileState extends State<_NotificationSettingTile> {
  late bool enabled;
  @override
  void initState() {
    super.initState();
    enabled = widget.enabled;
  }

  @override
  void didUpdateWidget(covariant _NotificationSettingTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    enabled = widget.enabled;
  }

  @override
  Widget build(BuildContext context) {
    Widget? subtitle;
    if (widget.category.description.isNotEmpty) {
      subtitle = Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(widget.category.description, maxLines: 2),
      );
    }

    if (widget.category.key == 'general') {
      // The general category is always enabled and can't be disabled.
      return SwitchListTile(
        value: true,
        onChanged: null,
        title: Text(widget.category.name.toUpperCase()),
        subtitle: subtitle,
      );
    }
    return SwitchListTile(
      value: enabled,
      onChanged: (value) async {
        final oldValue = enabled;
        final messenger = ScaffoldMessenger.of(context);
        try {
          setState(() => enabled = value);
          await BlocProvider.of<SettingsCubit>(
            context,
          ).setSetting(widget.category.key, value);
        } on ApiException {
          setState(() => enabled = oldValue);
          messenger.showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Could not change your notification settings.'),
            ),
          );
        }
      },
      title: Text(widget.category.name.toUpperCase()),
      subtitle: subtitle,
    );
  }
}

class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(
          'COLOR SCHEME',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        trailing: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return DropdownButton(
              value: themeMode,
              style: Theme.of(context).textTheme.bodyMedium,
              onChanged: (ThemeMode? newMode) async {
                BlocProvider.of<ThemeCubit>(context).change(newMode!);
              },
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Row(
                    children: [
                      Icon(Icons.wb_sunny_outlined),
                      SizedBox(width: 16),
                      Text('Light'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Row(
                    children: [
                      Icon(Icons.settings),
                      SizedBox(width: 16),
                      Text('System default'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Row(
                    children: [
                      Icon(Icons.brightness_2_outlined),
                      SizedBox(width: 16),
                      Text('Dark'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Image.asset(
                  Theme.of(context).brightness == Brightness.light
                      ? 'assets/img/logo-black.png'
                      : 'assets/img/logo-white.png',
                  width: 80,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ListBody(
                      children: <Widget>[
                        const SizedBox(height: 4),
                        Text(
                          'ThaliApp',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          Config.versionNumber,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'There is an app for everything.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                await launchUrl(
                  Config.changelogUri,
                  mode: LaunchMode.externalApplication,
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('CHANGELOG'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await launchUrl(
                  Config.feedbackUri,
                  mode: LaunchMode.externalApplication,
                );
              },
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('FEEDBACK'),
            ),
            OutlinedButton.icon(
              onPressed:
                  () => showLicensePage(
                    context: context,
                    applicationVersion: Config.versionNumber,
                    applicationIcon: Builder(
                      builder: (context) {
                        return Image.asset(
                          Theme.of(context).brightness == Brightness.light
                              ? 'assets/img/logo-black.png'
                              : 'assets/img/logo-white.png',
                          width: 80,
                        );
                      },
                    ),
                  ),
              label: const Text('VIEW LICENSES'),
              icon: const Icon(Icons.info_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogOutButton extends StatelessWidget {
  const _LogOutButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text('Log out'),
        onPressed: () async {
          Sentry.addBreadcrumb(Breadcrumb(message: 'logout button'));

          BlocProvider.of<AuthCubit>(context).logOut();
        },
      ),
    );
  }
}
