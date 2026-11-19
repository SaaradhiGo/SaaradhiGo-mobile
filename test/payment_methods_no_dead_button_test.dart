import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:saaradhigo_rider/l10n/app_localizations.dart';
import 'package:saaradhigo_rider/providers/wallet_provider.dart';
import 'package:saaradhigo_rider/screens/profile/manage_payment_methods_screen.dart';

/// 18 Nov (owner): "Add New Payment Method" did nothing (an empty onPressed). There is no saved
/// card to add (a card is entered at booking and held for the locked fare), so it is not shown.
void main() {
  testWidgets('Payment methods shows the wallet and no dead "Add New Payment Method" button', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<WalletProvider>(
      create: (_) => WalletProvider(),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ManagePaymentMethodsScreen(),
      ),
    ));
    await tester.pump();
    expect(find.text('SaaradhiGo Wallet'), findsOneWidget);
    expect(find.text('Add New Payment Method'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
