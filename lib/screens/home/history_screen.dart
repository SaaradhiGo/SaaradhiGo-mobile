import '../../core/vehicle_classes.dart';
import '../components/market_overlays.dart';
import 'package:flutter/material.dart';
import '../../ui/account_widgets.dart';
import '../../ui/sg_text.dart';
import '../../ui/sg_tokens.dart';
import '../../providers/map_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/history_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/models/trip_model.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().fetchHistory();
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  Map<String, List<Trip>> _groupTripsByMonth(List<Trip> trips) {
    final Map<String, List<Trip>> grouped = {};
    for (final trip in trips) {
      final monthYear = trip.createdAt != null
          ? DateFormat('MMMM yyyy').format(trip.createdAt!)
          : 'RECENTLY';
      if (!grouped.containsKey(monthYear)) {
        grouped[monthYear] = [];
      }
      grouped[monthYear]!.add(trip);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Consumer<HistoryProvider>(
        builder: (context, provider, child) {
          final groupedTrips = _groupTripsByMonth(provider.trips);
          final months = groupedTrips.keys.toList();

          return RefreshIndicator(
            edgeOffset: 20,
            color: SgColors.gold500,
            backgroundColor: SgColors.bg200,
            onRefresh: provider.fetchHistory,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: SgPageTitle('Your rides')),
                if (provider.isLoading && provider.trips.isEmpty)
                  _buildSkeletonSliver()
                else if (provider.errorMessage != null &&
                    provider.trips.isEmpty)
                  SliverFillRemaining(
                    child: _buildErrorState(provider.errorMessage!),
                  )
                else if (provider.trips.isEmpty)
                  SliverFillRemaining(child: _buildEmptyState())
                else
                  ...List.generate(months.length, (index) {
                    final month = months[index];
                    final trips = groupedTrips[month]!;
                    return SliverPadding(
                      padding: EdgeInsets.zero,
                      sliver: SliverMainAxisGroup(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                bottom: 16,
                                top: 8,
                              ),
                              child: Text(
                                month.toUpperCase(),
                                style: SgText.label,
                              ),
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              tripIndex,
                            ) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _HistoryRideCard(trip: trips[tripIndex]),
                              );
                            }, childCount: trips.length),
                          ),
                        ],
                      ),
                    );
                  }),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonSliver() {
    return SliverPadding(
      padding: EdgeInsets.zero,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Shimmer.fromColors(
              baseColor: SgColors.bg100,
              highlightColor: SgColors.bg200,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          childCount: 3,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.white.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 16),
          Text(
            'No rides yet',
            style: SgText.title,
          ),
          const SizedBox(height: 8),
          Text(
            'Rides you take will show here.',
            style: SgText.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFF87171)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFFE2E8F0),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.read<HistoryProvider>().fetchHistory(),
              style: ElevatedButton.styleFrom(
                backgroundColor: SgColors.gold500,
                foregroundColor: SgColors.onGold,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRideCard extends StatelessWidget {
  final Trip trip;

  const _HistoryRideCard({required this.trip});

  /// The same destination from where the rider is now, by the route the
  /// home screen uses for a saved place.
  Future<void> _rebook(BuildContext context) async {
    final provider = context.read<MapProvider>();
    if (provider.pickupLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set your pickup on the home screen first.')),
      );
      return;
    }
    context.push('/route-map');
    await provider.prepareAndCalculateRoute(
      pickupName: provider.pickupLocation!.name,
      dropPlaceId: '${trip.destinationLat},${trip.destinationLng}',
      dropName: trip.destinationAddress,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = trip.createdAt != null
        ? DateFormat('d MMM, h:mm a').format(trip.createdAt!)
        : 'Recently';
    final fare = trip.finalFare ?? trip.estimatedFare ?? '0';
    final canRebook = trip.destinationLat != null && trip.destinationLng != null;

    return Container(
      padding: const EdgeInsets.all(SgSpace.s4),
      decoration: BoxDecoration(
        color: SgColors.bg100,
        borderRadius: BorderRadius.circular(SgRadius.lg),
        border: Border.all(color: SgColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicleClassName(trip.vehicleType), style: SgText.title),
                    const SizedBox(height: 2),
                    Text(dateStr, style: SgText.caption),
                  ],
                ),
              ),
              // What was charged, exactly as the receipt says.
              Text('${marketOf(context).currencySymbol}$fare', style: SgText.fare),
            ],
          ),
          const SizedBox(height: SgSpace.s4),
          _TimelineRoute(
            pickup: trip.pickupAddress,
            destination: trip.destinationAddress,
          ),
          if (canRebook) ...[
            const SizedBox(height: SgSpace.s4),
            OutlinedButton(
              key: Key('rebook_${trip.id}'),
              onPressed: () => _rebook(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: SgColors.ink,
                side: const BorderSide(color: SgColors.lineStrong),
                minimumSize: const Size.fromHeight(kSgTouch),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SgRadius.md),
                ),
              ),
              child: Text('Ride here again',
                  style: SgText.body.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineRoute extends StatelessWidget {
  final String pickup;
  final String destination;

  const _TimelineRoute({required this.pickup, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: SgColors.pickup,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                pickup,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SgText.body,
              ),
            ),
          ],
        ),
        Row(
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: List.generate(
                  3,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    width: 2,
                    height: 4,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: Center(
                child: SizedBox(
                  width: 9,
                  height: 9,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: SgColors.gold500,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                destination,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SgText.body,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
