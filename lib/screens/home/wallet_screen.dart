import '../../ui/appearance_settings.dart' show sgStrings;
import '../components/market_overlays.dart';
import 'package:flutter/material.dart';
import '../../ui/account_widgets.dart';
import '../../ui/sg_text.dart';
import '../../ui/sg_tokens.dart';
import '../../ui/sg_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/remote_config_provider.dart';
import '../../services/models/wallet_model.dart';
import '../../utils/money.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String _selectedFilter = 'All';
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().refreshWallet();
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMore() {
    setState(() {
      _currentPage++;
    });
  }

  List<Transaction> _getFilteredTransactions(List<Transaction> transactions) {
    if (_selectedFilter == 'All') return transactions;
    if (_selectedFilter == 'Credits' || _selectedFilter == 'Recharges') {
      return transactions.where((t) => t.isCredit).toList();
    }
    if (_selectedFilter == 'Payments') {
      return transactions.where((t) => !t.isCredit).toList();
    }
    return transactions;
  }

  List<Transaction> _getPaginatedTransactions(List<Transaction> filtered) {
    final start = 0;
    final end = _currentPage * _itemsPerPage;
    if (end >= filtered.length) return filtered;
    return filtered.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, provider, child) {
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: RefreshIndicator(
            onRefresh: provider.refreshWallet,
            color: SgColors.gold500,
            backgroundColor: SgColors.bg200,
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SgPageTitle('Wallet'),
                Consumer<RemoteConfigProvider>(
                  builder: (context, cfg, _) => _WalletBalanceCard(
                    balance: provider.balance,
                    pendingReview: provider.wallet?.hasPendingReview == true
                        ? formatServerMoney(
                            provider.wallet!.pendingReview,
                            provider.wallet!.currency,
                          )
                        : null,
                    isLoading: provider.isLoading,
                    topupsEnabled: cfg.walletTopupsEnabled,
                    creditsOnly: cfg.walletCreditsOnly,
                  ),
                ),
                Consumer<RemoteConfigProvider>(
                  builder: (context, cfg, _) {
                    if (!cfg.walletCreditsOnly) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Earned from refunds, promos, and customer support credits. '
                        'Apply at checkout on your next ride.',
                        style: SgText.caption,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                _buildFilterChips(),
                const SizedBox(height: 16),
                if (provider.isLoading && provider.transactions.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(color: SgColors.gold500),
                    ),
                  )
                else if (provider.errorMessage != null &&
                    provider.transactions.isEmpty)
                  _ErrorState(message: provider.errorMessage!)
                else if (provider.transactions.isEmpty)
                  const _EmptyTransactionsState()
                else
                  ..._buildTransactionHistory(provider.transactions),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildTransactionHistory(List<Transaction> transactions) {
    final filtered = _getFilteredTransactions(transactions);
    final paginated = _getPaginatedTransactions(filtered);

    // Group transactions by month
    final Map<String, List<Transaction>> grouped = {};
    final DateFormat monthFormat = DateFormat('MMMM yyyy');

    for (var tx in paginated) {
      final month = monthFormat.format(tx.dateTime);
      grouped.putIfAbsent(month, () => []).add(tx);
    }

    final List<Widget> widgets = [];
    grouped.forEach((month, txs) {
      widgets.add(_WalletMonthLabel(label: month));
      widgets.add(const SizedBox(height: 14));
      for (int i = 0; i < txs.length; i++) {
        widgets.add(
          _WalletTxnCard(
            transaction: txs[i],
            showTimelineTail: i < txs.length - 1,
          ),
        );
        widgets.add(const SizedBox(height: 12));
      }
      widgets.add(const SizedBox(height: 12));
    });

    // Add Load More button if there are more transactions
    if (filtered.length > paginated.length) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ElevatedButton(
            onPressed: _loadMore,
            style: ElevatedButton.styleFrom(
              backgroundColor: SgColors.bg300,
              foregroundColor: SgColors.ink,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Show more',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildFilterChips() {
    return Consumer<RemoteConfigProvider>(
      builder: (context, cfg, _) {
        final creditsLabel = cfg.walletCreditsOnly ? 'Credits' : 'Recharges';
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: sgStrings(context).filterAll,
                isSelected: _selectedFilter == 'All',
                onTap: () => setState(() {
                  _selectedFilter = 'All';
                  _currentPage = 1;
                }),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: creditsLabel,
                isSelected:
                    _selectedFilter == creditsLabel ||
                    _selectedFilter == 'Recharges' ||
                    _selectedFilter == 'Credits',
                onTap: () => setState(() {
                  _selectedFilter = creditsLabel;
                  _currentPage = 1;
                }),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: sgStrings(context).filterPayments,
                isSelected: _selectedFilter == 'Payments',
                onTap: () => setState(() {
                  _selectedFilter = 'Payments';
                  _currentPage = 1;
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WalletBalanceCard extends StatelessWidget {
  const _WalletBalanceCard({
    required this.balance,
    required this.isLoading,
    required this.topupsEnabled,
    required this.creditsOnly,
    this.pendingReview,
  });
  final double balance;

  /// A reward held for review, already formatted; null hides the line.
  final String? pendingReview;
  final bool isLoading;
  final bool topupsEnabled;
  final bool creditsOnly;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      symbol: marketOf(context).currencySymbol,
      decimalDigits: 2,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SgColors.bg100,
        borderRadius: BorderRadius.circular(SgRadius.lg),
        border: Border.all(color: SgColors.goldLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                creditsOnly ? 'SaaradhiGo credits' : 'Balance',
                style: SgText.body.copyWith(color: SgColors.inkMuted),
              ),
              SgIcon(SgIcons.wallet, size: 20, color: SgColors.inkMuted),
            ],
          ),
          const SizedBox(height: 8),
          isLoading && balance == 0
              ? const SizedBox(
                  height: 40,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: SgColors.gold500,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : Text(
                  formatter.format(balance),
                  style: SgText.fare.copyWith(fontSize: 36, height: 44 / 36),
                ),
          if (pendingReview != null) ...[
            const SizedBox(height: 8),
            Text(
              'Pending review: $pendingReview (not spendable yet)',
              key: const Key('wallet_pending_review'),
              style: SgText.caption,
            ),
          ],
          if (topupsEnabled) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _WalletActionButton(
                    icon: Icons.add_rounded,
                    label: sgStrings(context).addMoney,
                    onTap: () {
                      context.push('/add-money');
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WalletMonthLabel extends StatelessWidget {
  const _WalletMonthLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(), style: SgText.label);
  }
}

class _WalletTxnCard extends StatelessWidget {
  const _WalletTxnCard({
    required this.transaction,
    required this.showTimelineTail,
  });

  final Transaction transaction;
  final bool showTimelineTail;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat(
      'MMM dd, yyyy \u2022 hh:mm a',
    ).format(transaction.dateTime);

    Color getStatusColor() {
      final s = transaction.status.toLowerCase();
      if (s == 'success' || s == 'completed') return SgColors.success;
      if (s == 'failed') return SgColors.danger;
      if (s == 'pending') return SgColors.goldText;
      return SgColors.inkMuted;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: transaction.isCredit
                    ? SgColors.success
                    : SgColors.gold500,
              ),
            ),
            if (showTimelineTail)
              Container(width: 2, height: 48, color: SgColors.bg300),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SgColors.bg300,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SgColors.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              transaction.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: SgColors.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: getStatusColor().withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: getStatusColor().withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              transaction.status.toUpperCase(),
                              style: TextStyle(
                                color: getStatusColor(),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: SgColors.inkMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  transaction.formattedAmount,
                  style: TextStyle(
                    color: transaction.isCredit
                        ? SgColors.success
                        : SgColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyTransactionsState extends StatelessWidget {
  const _EmptyTransactionsState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Icons.history_rounded, size: 64, color: SgColors.inkSubtle),
        const SizedBox(height: 16),
        Text(
          'No transactions yet',
          style: TextStyle(
            color: SgColors.inkMuted,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Icons.error_outline_rounded, size: 64, color: SgColors.danger),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SgColors.danger,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.read<WalletProvider>().refreshWallet(),
          child: Text(sgStrings(context).retry, style: TextStyle(color: SgColors.goldText)),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? SgColors.bg300 : SgColors.bg100,
          borderRadius: BorderRadius.circular(SgRadius.pill),
          border: Border.all(
            color: isSelected ? SgColors.lineStrong : SgColors.line,
          ),
        ),
        child: Text(
          label,
          style: SgText.body.copyWith(
            fontWeight: FontWeight.w700,
            color: isSelected ? SgColors.ink : SgColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _WalletActionButton extends StatelessWidget {
  const _WalletActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: SgColors.bg200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SgColors.goldText.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: SgColors.goldText, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: SgColors.goldText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
