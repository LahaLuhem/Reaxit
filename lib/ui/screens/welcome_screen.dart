import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reaxit/blocs/welcome_cubit.dart';
import 'package:reaxit/ui/router/router.dart';
import 'package:reaxit/ui/screens/calendar_screen.dart';
import 'package:reaxit/ui/widgets/app_bar.dart';
import 'package:reaxit/ui/widgets/error_scroll_view.dart';
import 'package:reaxit/ui/widgets/event_detail_card.dart';
import 'package:reaxit/ui/widgets/menu_drawer.dart';

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ThaliaAppBar(title: Text('Welcome')),
      drawer: MenuDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          await BlocProvider.of<WelcomeCubit>(context).load();
        },
        child: BlocBuilder<WelcomeCubit, WelcomeState>(
          builder: (context, state) {
            if (state.hasException) {
              return ErrorScrollView(state.message!);
            } else {
              // TODO: Add date headers, with 'Tomorrow', etc. where possible.
              return ListView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (state.result != null)
                    ...state.result!.map(
                      (event) => EventDetailCard(event: event),
                    ),
                  TextButton(
                    onPressed: () => ThaliaRouterDelegate.of(context).replace(
                      MaterialPage(child: CalendarScreen()),
                    ),
                    child: Text('SHOW THE ENTIRE AGENDA'),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}
