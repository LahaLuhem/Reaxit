import 'package:flutter/material.dart';
import '../router.dart';
import 'package:reaxit/ui/widgets/app_bar.dart';
import 'package:reaxit/ui/widgets/menu_drawer.dart';

import 'vacancy_screen.dart';

class VacanciesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    var controller = ScrollController();
    return Scaffold(
      appBar: ThaliaAppBar(title: const Text('VACANCIES')),
      drawer: MenuDrawer(),
      body: Scrollbar(
        controller: controller,
        child: ListView(
          padding: const EdgeInsets.all(16),
          controller: controller,
          children: [
            Text(
              'internships',
              style: textTheme.caption,
            ),
            _makeVacancyCard(context, 'ASMR (ASML maar beter)',
                'idk hier staat iets over werk dat je waarschijnlijk niet echt wilt doen ofzo maar wel moet doen want geld is redelijk handig in het leven tenzij je natuurlijk niet leeft wat ook een optie is en misschien wel de beste optie maarja dat vinden anderen meestal geen geweldig plan dus dat maar niet dan.'),
            _makeVacancyCard(context, 'ORCAS ZiJN ONDErWATERPANDAS',
                'JEP. WIST JE NIET HE? Deze tekst kan trouwens ook zonder caps ik was gwn vergeten m uit te zetten. Deze tekst is niet lang genoeg dus ik ga er nog wat bij typen want anders is het niet lang genoeg dus type ik er nog wat bij haha haha haha ja idk doei dit is vast genoeg.'),
            _makeVacancyCard(context, 'TOAST (YOAST maar beter)',
                'ha ha ha ha nee ik heb echt geen inspiratie meer hiervoor maar iets van een beschrijving ofzo doei dag doei laters ofzo idk wtf man ik wil niet schrijven hier maar doe het toch help ik kan niet meer stoppen het houd nooit op denk ik het gaat niet meer stoppen.'),
            const Padding(padding: EdgeInsets.only(top: 8)),
            Text(
              'externboats',
              style: textTheme.caption,
            ),
            _makeVacancyCard(context, 'ASMR (ASML maar beter)',
                'Haha echt zin om van erasmus te yeeten als ASMR me nu geen goed salaris gaat betalen haha lol lmao.'),
            _makeVacancyCard(context, 'TOAST (YOAST maar beter)',
                'Sorry maar ehhhh... BABY SHARK DOO DOO DO DO DO DO, BABY SHARK DOO DOO DO DO. sorry ik stop al maar je gaat dit liedje nu de komende week in je hoofd hebben doei.'),
            const Padding(padding: EdgeInsets.only(top: 8)),
            Text(
              'old professionals',
              style: textTheme.caption,
            ),
            _makeVacancyCard(
                context,
                'Manager of branch expertise relation resources and consulting.',
                'idk hier staat iets over werk dat je waarschijnlijk niet echt wilt doen ofzo maar wel moet doen want geld is redelijk handig in het leven tenzij je natuurlijk niet leeft wat ook een optie is en misschien wel de beste optie maarja dat vinden anderen meestal geen geweldig plan dus dat maar niet dan.'),
            _makeVacancyCard(context, 'Taiwan is het Drenthe van China inc.',
                'ha ha ha ha nee ik heb echt geen inspiratie meer hiervoor maar iets van een beschrijving ofzo doei dag doei laters ofzo idk wtf man ik wil niet schrijven hier maar doe het toch help ik kan niet meer stoppen het houd nooit op denk ik het gaat niet meer stoppen.'),
          ],
        ),
      ),
    );
  }

  Widget _makeVacancyCard(
      BuildContext context, String vacancyTitle, String vacancyDescription) {
    final textTheme = Theme.of(context).textTheme;
    final routerDelegate = ThaliaRouterDelegate.of(context);
    return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: InkWell(
          onTap: () {
            routerDelegate.replace(
                TypedMaterialPage(child: VacancyScreen(), name: 'Vacancy'));
          },
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vacancyTitle,
                      style: textTheme.subtitle1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      vacancyDescription,
                      style: textTheme.bodyText2,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ])),
        ));
  }
}