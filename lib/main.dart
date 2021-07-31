import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:reaxit/blocs/album_list_bloc.dart';
import 'package:reaxit/blocs/auth_bloc.dart';
import 'package:reaxit/blocs/event_list_bloc.dart';
import 'package:reaxit/blocs/full_member_cubit.dart';
import 'package:reaxit/blocs/member_list_bloc.dart';
import 'package:reaxit/blocs/payment_user_cubit.dart';
import 'package:reaxit/blocs/setting_cubit.dart';
import 'package:reaxit/blocs/theme_bloc.dart';
import 'package:reaxit/blocs/welcome_cubit.dart';
import 'package:reaxit/config.dart' as config;
import 'package:reaxit/theme.dart';
import 'package:reaxit/ui/router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = config.sentryDSN;
    },
    appRunner: () async {
      runApp(BlocProvider(
        create: (_) => ThemeBloc()..add(ThemeLoadEvent()),
        lazy: false,
        child: BlocProvider(
          create: (context) => AuthBloc()..add(LoadAuthEvent()),
          child: ThaliApp(),
        ),
      ));
    },
  );
}

class ThaliApp extends StatefulWidget {
  @override
  _ThaliAppState createState() => _ThaliAppState();
}

class _ThaliAppState extends State<ThaliApp> {
  late final ThaliaRouterDelegate _routerDelegate;
  late final ThaliaRouteInformationParser _routeInformationParser;

  final _firebaseInitialization = Firebase.initializeApp();

  @override
  void initState() {
    super.initState();
    _routeInformationParser = ThaliaRouteInformationParser();
    _routerDelegate = ThaliaRouterDelegate(
      authBloc: BlocProvider.of<AuthBloc>(context),
      firebaseInitialization: _firebaseInitialization,
    );
  }

  @override
  void dispose() {
    _routerDelegate.dispose();
    super.dispose();
  }

  /// This key prevents initializing a new [MaterialApp] state and, through
  /// that, a new [Router] state, that would otherwise unintentionally make
  /// an additional call to [ThaliaRouterDelegate.setInitialRoutePath] on
  /// authentication events.
  final _materialAppKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return OverlaySupport(child: BlocBuilder<ThemeBloc, ThemeMode>(
      builder: (context, themeMode) {
        return BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            if (authState is LoggedInAuthState) {
              return RepositoryProvider.value(
                value: authState.apiRepository,
                child: MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (_) => PaymentUserCubit(
                        authState.apiRepository,
                      )..load(),
                      lazy: false,
                    ),
                    BlocProvider(
                      create: (_) => FullMemberCubit(
                        authState.apiRepository,
                      )..load(),
                      lazy: false,
                    ),
                    BlocProvider(
                      create: (_) => WelcomeCubit(
                        authState.apiRepository,
                      )..load(),
                      lazy: false,
                    ),
                    BlocProvider(
                      create: (_) => EventListBloc(
                        authState.apiRepository,
                      )..add(EventListEvent.load()),
                      lazy: false,
                    ),
                    BlocProvider(
                      create: (_) => MemberListBloc(
                        authState.apiRepository,
                      )..add(const MemberListEvent.load()),
                      lazy: false,
                    ),
                    BlocProvider(
                      create: (_) => AlbumListBloc(
                        authState.apiRepository,
                      )..add(const AlbumListEvent.load()),
                      lazy: false,
                    ),
                    BlocProvider(
                      create: (_) => SettingsCubit(
                        authState.apiRepository,
                        _firebaseInitialization,
                      )..load(),
                      lazy: true,
                    ),
                  ],
                  child: MaterialApp.router(
                    key: _materialAppKey,
                    title: 'ThaliApp',
                    theme: lightTheme,
                    darkTheme: darkTheme,
                    themeMode: themeMode,
                    routerDelegate: _routerDelegate,
                    routeInformationParser: _routeInformationParser,
                  ),
                ),
              );
            } else {
              return MaterialApp.router(
                key: _materialAppKey,
                title: 'ThaliApp',
                theme: lightTheme,
                darkTheme: darkTheme,
                themeMode: themeMode,
                routerDelegate: _routerDelegate,
                routeInformationParser: _routeInformationParser,
              );
            }
          },
        );
      },
    ));
  }
}
