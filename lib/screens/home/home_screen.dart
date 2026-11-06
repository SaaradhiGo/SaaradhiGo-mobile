import '../../utils/position.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/notification_provider.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/market/market_config_store.dart';
import '../../ui/account_widgets.dart';
import '../../ui/home_widgets.dart';
import '../../ui/sg_appearance.dart';
import '../../services/home_fares.dart';
import '../../ui/sg_text.dart';
import '../../ui/sg_tokens.dart';
import '../../ui/sg_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../providers/map_provider.dart';
import '../../services/map_service.dart';
import '../components/market_overlays.dart' show marketOf;
import '../../screens/components/coming_soon_overlay.dart';
import 'history_screen.dart';
import 'wallet_screen.dart';
import '../../ui/appearance_settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late int _tabIndex;
  final ValueNotifier<bool> _searchOpen = ValueNotifier<bool>(false);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropController = TextEditingController();
  final FocusNode _pickupFocusNode = FocusNode();
  final FocusNode _dropFocusNode = FocusNode();
  bool _isGettingLocation = false;
  LatLng? _currentPosition;

  // Context safety: store references to providers
  MapProvider? _mapProvider;
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabIndex = widget.initialTabIndex.clamp(0, 3).toInt();

    // Listen to MapProvider for real-time redirection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _getCurrentLocation();
      context.read<MapProvider>().fetchDynamicHomeData();
      context.read<NotificationProvider>().fetchNotifications();

      _mapProvider = context.read<MapProvider>();
      _mapProvider?.addListener(_onMapProviderChanged);

      _checkAndRedirectActiveRide();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Use stored reference instead of context.read in dispose
    _mapProvider?.removeListener(_onMapProviderChanged);
    _pickupController.dispose();
    _dropController.dispose();
    _pickupFocusNode.dispose();
    _dropFocusNode.dispose();
    _searchOpen.dispose();
    super.dispose();
  }

  Future<void> _checkAndRedirectActiveRide({bool isAutomatic = false}) async {
    if (!mounted || _isRedirecting) return;

    final mapProvider = _mapProvider ?? context.read<MapProvider>();

    // Safety: If we are already redirecting, or if the provider is in a stable state
    // that matches the current screen, we should avoid redundant checks.

    String currentRoute = '';
    try {
      // Use the router's state safely. If this fails, we are likely detached.
      currentRoute = GoRouter.of(
        context,
      ).routerDelegate.currentConfiguration.last.matchedLocation;
    } catch (e) {
      debugPrint('Guard: Failed to get current route, likely detached: $e');
      return;
    }

    if (!mounted) return;

    // Determine target based on provider state
    String? targetRoute;

    // Priority 1: Check actual ride status from response
    if (mapProvider.rideRequestResponse != null) {
      final status = mapProvider.rideRequestResponse['status'];
      if (status == 'accept' || status == 'reached') {
        targetRoute = '/driver-found';
      } else if (status == 'start' || status == 'active') {
        targetRoute = '/tracking';
      }
    }

    // Priority 2: Check if currently searching
    if (targetRoute == null && mapProvider.isRequestingRide) {
      targetRoute = '/searching-driver';
    }

    // Priority 3: Persistent check (for app restarts/deep links)
    if (targetRoute == null) {
      // Only do a server check if we are NOT in an automatic listener update
      // and we are currently on the Home tab.
      if (!isAutomatic && _tabIndex == 0) {
        final status = await mapProvider.checkActiveRide();
        if (!mounted) return;
        if (status == 'searching') {
          targetRoute = '/searching-driver';
        } else if (status == 'accept' || status == 'arrive') {
          targetRoute = '/driver-found';
        } else if (status == 'start' || status == 'active') {
          targetRoute = '/tracking';
        }
      }
    }

    // ONLY redirect if we are moving TO a ride screen FROM a non-ride screen (like home)
    // or if we are clearly on the wrong ride screen.
    final rideScreens = ['/searching-driver', '/driver-found', '/tracking'];
    bool onRideScreen = rideScreens.contains(currentRoute);

    if (targetRoute != null && targetRoute != currentRoute) {
      // If we are already on some ride screen, don't jump around unless it's a forward progression
      // The individual screens handle their own forward progression listeners.
      if (onRideScreen && isAutomatic) return;

      debugPrint('Redirecting to $targetRoute (current: $currentRoute)');
      _isRedirecting = true;

      if (!isAutomatic) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SgColors.gold500,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Resuming your active ride...'),
                ],
              ),
              duration: Duration(seconds: 1),
            ),
          );
        } catch (_) {}
      }

      context.push(targetRoute);

      // Keep guard active long enough for navigation to settle
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _isRedirecting = false;
      });
    }
  }

  void _onMapProviderChanged() {
    if (!mounted || _isRedirecting) return;

    // Passive guard: only trigger if we are on the Home screen
    String currentRoute = '';
    try {
      currentRoute = GoRouter.of(
        context,
      ).routerDelegate.currentConfiguration.last.matchedLocation;
    } catch (_) {
      return;
    }

    if (currentRoute != '/home') return;

    final mapProvider = _mapProvider ?? context.read<MapProvider>();

    // Check for coming soon overlay
    if (mapProvider.showComingSoonOverlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => const ComingSoonOverlay(),
          ).then((_) {
            // Dismiss the flag after dialog closes
            mapProvider.dismissComingSoonOverlay();
          });
        }
      });
    }

    if (mapProvider.isTripInProgress) {
      _checkAndRedirectActiveRide(isAutomatic: true);
    }
  }

  void _showActiveRideBookingGuard() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SgColors.bg200,
        title: Text(
          'Active Ride',
          style: TextStyle(color: SgColors.ink, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'You already have an active ride request or trip. Would you like to view it?',
          style: TextStyle(color: SgColors.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Dismiss', style: TextStyle(color: SgColors.inkMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkAndRedirectActiveRide();
            },
            child: Text(
              'View Ride',
              style: TextStyle(
                color: SgColors.goldText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location services are disabled. Please enable them in settings.',
              ),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permissions are permanently denied, we cannot request permissions.',
              ),
            ),
          );
        }
        return;
      }

      final position = await currentOrLastKnownPosition();
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "We couldn't find your location. Enter your pickup point.",
              ),
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      }

      if (mounted) {
        String addressText = "Current Location";
        final mapService = MapService();
        final fetchedAddress = await mapService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (fetchedAddress != null && fetchedAddress.isNotEmpty) {
          addressText = fetchedAddress;
        }

        if (mounted) {
          _pickupController.text = addressText;
          final provider = context.read<MapProvider>();
          await provider.setPickupLocation(
            'current',
            defaultName: addressText,
            presetLocation: LatLng(position.latitude, position.longitude),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _HomeTab(
        pickupController: _pickupController,
        dropController: _dropController,
        pickupFocusNode: _pickupFocusNode,
        dropFocusNode: _dropFocusNode,
        onLocationTap: _getCurrentLocation,
        isGettingLocation: _isGettingLocation,
        currentPosition: _currentPosition,
        onActiveRideTap: _showActiveRideBookingGuard,
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        onProfileTap: () => setState(() => _tabIndex = 3),
        searchOpen: _searchOpen,
      ),
      const HistoryScreen(),
      const WalletScreen(),
      _ProfileTab(onWallet: () => setState(() => _tabIndex = 2)),
    ];
    final l = sgStrings(context);

    return PopScope(
      // Back from History, Wallet or Profile returns home.
      canPop: _tabIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tabIndex = 0);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: SgColors.bg000,
        drawer: _MenuDrawer(
          onTab: (index) => setState(() => _tabIndex = index),
        ),
        // Ride, Trips, Account. Wallet opens from Account and shows under it.
        bottomNavigationBar: SgTabBar(
          items: [
            SgTabItem(
              key: const Key('home-nav-home'),
              icon: SgIcons.home,
              label: l.tabRide,
            ),
            SgTabItem(
              key: const Key('home-nav-trips'),
              icon: SgIcons.history,
              label: l.tabTrips,
            ),
            SgTabItem(
              key: const Key('home-nav-profile'),
              icon: SgIcons.user,
              label: l.tabAccount,
            ),
          ],
          selected: switch (_tabIndex) {
            0 => 0,
            1 => 1,
            _ => 2,
          },
          onSelect: (i) => setState(() => _tabIndex = const [0, 1, 3][i]),
        ),
        body: _tabIndex == 0
            ? tabs[0]
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_tabIndex == 2)
                        IconButton(
                          tooltip: 'Back',
                          constraints: const BoxConstraints(
                            minWidth: kSgTouch,
                            minHeight: kSgTouch,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () => setState(() => _tabIndex = 3),
                          icon: SgIcon(
                            SgIcons.back,
                            size: 24,
                            color: SgColors.ink,
                          ),
                        ),
                      Expanded(child: tabs[_tabIndex]),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// The menu: who is signed in, then every place the app has.
class _MenuDrawer extends StatelessWidget {
  const _MenuDrawer({required this.onTab});

  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    Widget row(
      String icon,
      String label,
      VoidCallback onTap, {
      int count = 0,
      Key? key,
    }) => SgListRow(
      key: key,
      icon: icon,
      label: label,
      count: count,
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );

    final auth = context.watch<AuthProvider>();
    final unread = context.watch<NotificationProvider>().unreadCount;
    return Drawer(
      backgroundColor: SgColors.bg100,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SgSpace.s5,
            SgSpace.s4,
            SgSpace.s5,
            SgSpace.s4,
          ),
          children: [
            SgPersonHeader(
              name: auth.fullName,
              rating: auth.rating,
              avatarUrl: auth.avatarUrl,
              onTap: () {
                Navigator.of(context).pop();
                onTab(3);
              },
            ),
            const SizedBox(height: SgSpace.s3),
            Divider(height: 1, color: SgColors.line),
            const SizedBox(height: SgSpace.s2),
            row(
              SgIcons.history,
              'Your rides',
              () => onTab(1),
              key: const Key('menu_rides'),
            ),
            row(
              SgIcons.wallet,
              'Wallet',
              () => onTab(2),
              key: const Key('menu_wallet'),
            ),
            row(
              kCardIcon,
              'Payment methods',
              () => context.push('/payment-methods'),
            ),
            row(
              SgIcons.bell,
              'Notifications',
              () => context.push('/notifications'),
              count: unread,
            ),
            if (MarketConfigStore.instance.current.referralsAvailable)
              row(kGiftIcon, 'Refer a friend', () => context.push('/refer')),
            row(
              SgIcons.user,
              'Profile',
              () => onTab(3),
              key: const Key('menu_profile'),
            ),
            row(
              SgIcons.help,
              'Help and support',
              () => context.push('/help-support'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.pickupController,
    required this.dropController,
    required this.pickupFocusNode,
    required this.dropFocusNode,
    required this.onLocationTap,
    required this.isGettingLocation,
    this.currentPosition,
    required this.onActiveRideTap,
    required this.onMenuTap,
    required this.onProfileTap,
    required this.searchOpen,
  });

  final TextEditingController pickupController;
  final TextEditingController dropController;
  final FocusNode pickupFocusNode;
  final FocusNode dropFocusNode;
  final VoidCallback onLocationTap;
  final bool isGettingLocation;
  final LatLng? currentPosition;
  final VoidCallback onActiveRideTap;
  final VoidCallback onMenuTap;
  final VoidCallback onProfileTap;
  final ValueNotifier<bool> searchOpen;

  Future<void> _goTo(
    BuildContext context,
    String dropPlaceId, {
    String? dropName,
  }) async {
    final provider = context.read<MapProvider>();
    if (provider.isTripInProgress) {
      onActiveRideTap();
      return;
    }
    // Check if pickup is loaded before navigating
    if (provider.pickupLocation == null && currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select pickup location first'),
          backgroundColor: SgColors.gold500,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Navigate immediately, calculate route in background
    context.push('/route-map');
    try {
      await provider.prepareAndCalculateRoute(
        pickupName: pickupController.text.isNotEmpty
            ? pickupController.text
            : 'Current Location',
        presetPickup: currentPosition,
        dropPlaceId: dropPlaceId,
        dropName: dropName,
      );
    } catch (e) {
      // Pickup outside our service area: show ComingSoonOverlay and stop.
      if (e.toString().contains('Pickup location outside our service area')) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => const ComingSoonOverlay(),
          );
        }
        return;
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();
    final auth = context.watch<AuthProvider>();
    final l = sgStrings(context);
    final here = mapProvider.pickupLocation?.latLng ?? currentPosition;
    final first = homeFirstName(auth.fullName);
    // Saved places have labels only when the server sends them; otherwise
    // their address text. Up to two, quoted while the home is on screen.
    final places = pickHomePlaces(
      mapProvider.favoriteLocations,
      mapProvider.recentLocations,
    );

    return ValueListenableBuilder<bool>(
      valueListenable: searchOpen,
      builder: (context, open, _) => PopScope(
        canPop: !open,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          pickupFocusNode.unfocus();
          dropFocusNode.unfocus();
        },
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SgSpace.s4,
              SgSpace.s2,
              SgSpace.s4,
              SgSpace.s5,
            ),
            children: [
              if (!open) ...[
                HomeHeader(
                  languageShort: languageShort(SgAppearance.instance.language),
                  onLanguage: () => showLanguagePicker(context),
                  name: auth.fullName,
                  avatarUrl: auth.avatarUrl,
                  onAccount: onProfileTap,
                ),
                const SizedBox(height: SgSpace.s5),
                Text(
                  first.isEmpty ? l.homeHeadline : l.homeHeadlineNamed(first),
                  key: const Key('home_headline'),
                  style: SgText.display,
                ),
                const SizedBox(height: SgSpace.s4),
              ],
              // Keyed: opening the search removes the lines above it, and an
              // unkeyed field would be rebuilt there, losing focus and the
              // keyboard.
              KeyedSubtree(
                key: const ValueKey('home-search'),
                child: _LocationCard(
                  pickupController: pickupController,
                  dropController: dropController,
                  pickupFocusNode: pickupFocusNode,
                  dropFocusNode: dropFocusNode,
                  onLocationTap: onLocationTap,
                  isGettingLocation: isGettingLocation,
                  currentPosition: currentPosition,
                  onActiveRideTap: onActiveRideTap,
                  searchOpen: searchOpen,
                ),
              ),
              if (!open) ...[
                if (mapProvider.isTripInProgress) ...[
                  const SizedBox(height: SgSpace.s3),
                  _ActiveRideTile(onTap: onActiveRideTap),
                ],
                const SizedBox(height: SgSpace.s5),
                if (places.isNotEmpty || mapProvider.isLoadingHomeData) ...[
                  SgEyebrow(l.faresFromHere),
                  const SizedBox(height: SgSpace.s3),
                ],
                if (places.isEmpty && mapProvider.isLoadingHomeData)
                  const Padding(
                    padding: EdgeInsets.all(SgSpace.s4),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SgColors.gold500,
                        ),
                      ),
                    ),
                  )
                else
                  _HomeFares(
                    here: here,
                    places: places,
                    fallback: l.tapToSeeFares,
                    onOpen: (place, type) {
                      if (type != null) {
                        context.read<MapProvider>().selectVehicleType(type);
                      }
                      _goTo(
                        context,
                        '${place.to.latitude},${place.to.longitude}',
                        dropName: place.address ?? place.name,
                      );
                    },
                  ),
                const SizedBox(height: SgSpace.s4),
                FareLockLine(l.fareLockLine),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The fare cards: one per place, each quoted on its own so a slow place does
/// not hold up the other.
class _HomeFares extends StatefulWidget {
  const _HomeFares({
    required this.here,
    required this.places,
    required this.fallback,
    required this.onOpen,
  });

  final LatLng? here;
  final List<HomePlace> places;
  final String fallback;
  final void Function(HomePlace place, String? type) onOpen;

  @override
  State<_HomeFares> createState() => _HomeFaresState();
}

class _HomeFaresState extends State<_HomeFares> {
  final _service = HomeFares();
  final Map<String, HomeQuote> _quotes = {};
  final Set<String> _loading = {};
  String _signature = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _HomeFares old) {
    super.didUpdateWidget(old);
    _refresh();
  }

  String _sig() =>
      '${widget.here?.latitude.toStringAsFixed(3)},'
      '${widget.here?.longitude.toStringAsFixed(3)}|'
      '${widget.places.map((p) => p.name).join('|')}';

  void _refresh() {
    final sig = _sig();
    if (sig == _signature) return;
    _signature = sig;
    final from = widget.here;
    if (from == null) return;
    for (final p in widget.places) {
      final hit = _service.cached(from, p);
      if (hit != null) {
        _quotes[p.name] = hit;
        continue;
      }
      _loading.add(p.name);
      _service.quote(from, p).then((q) {
        if (!mounted) return;
        setState(() {
          _loading.remove(p.name);
          _quotes[p.name] = q;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final market = marketOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in widget.places) ...[
          Builder(
            builder: (context) {
              final q = _quotes[p.name];
              final meta = (q?.distanceKm == null || q?.durationMin == null)
                  ? null
                  : '${market.formatDistanceKm(q!.distanceKm!)} · ${durationLabel(q.durationMin!)}';
              return HomeFareCard(
                key: Key('home_fare_${p.name}'),
                name: p.name,
                meta: meta,
                loading: widget.here != null && _loading.contains(p.name),
                fallback: widget.fallback,
                onTap: () => widget.onOpen(p, null),
                chips: [
                  for (final f in q?.fares ?? const <HomeClassFare>[])
                    HomeClassChip(
                      type: f.type,
                      fareText: f.fareText,
                      onTap: () => widget.onOpen(p, f.type),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: SgSpace.s3),
        ],
      ],
    );
  }
}

// History screen is now a separate component

// Wallet screen is now a separate component

// Profile tab implementation

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.onWallet});

  final VoidCallback onWallet;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SgPageTitle('Profile'),
        // Only what the account holds: no stock photo, name or rating.
        SgPersonHeader(
          name: auth.fullName,
          rating: auth.rating,
          avatarUrl: auth.avatarUrl,
          onTap: () => context.push('/personal-info'),
        ),
        const SizedBox(height: SgSpace.s5),
        SgListGroup([
          SgListRow(
            icon: SgIcons.user,
            label: 'Personal information',
            chevron: true,
            onTap: () => context.push('/personal-info'),
          ),
          SgListRow(
            key: const Key('profile_wallet'),
            icon: SgIcons.wallet,
            label: sgStrings(context).wallet,
            chevron: true,
            onTap: onWallet,
          ),
          SgListRow(
            icon: kCardIcon,
            label: 'Payment methods',
            chevron: true,
            onTap: () => context.push('/payment-methods'),
          ),
          SgListRow(
            icon: SgIcons.bell,
            label: 'Notifications',
            chevron: true,
            onTap: () => context.push('/notifications'),
          ),
          SgListRow(
            icon: SgIcons.lock,
            label: 'Privacy and security',
            chevron: true,
            onTap: () => context.push('/privacy-security'),
          ),
          SgListRow(
            icon: SgIcons.help,
            label: 'Help and support',
            chevron: true,
            onTap: () => context.push('/help-support'),
          ),
          // Hidden unless a referral offer is live for riders in this market.
          if (MarketConfigStore.instance.current.referralsAvailable)
            SgListRow(
              icon: kGiftIcon,
              label: 'Refer a friend',
              chevron: true,
              onTap: () => context.push('/refer'),
            ),
        ]),
        const SizedBox(height: SgSpace.s5),
        SgListGroup(appearanceRows(context)),
        const SizedBox(height: SgSpace.s5),
        SgListGroup([
          SgListRow(
            key: const Key('profile_logout'),
            icon: kLogoutIcon,
            label: 'Log out',
            danger: true,
            onTap: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              context.go('/login');
            },
          ),
        ]),
        const SizedBox(height: SgSpace.s6),
      ],
    );
  }
}

class _LocationCard extends StatefulWidget {
  const _LocationCard({
    required this.pickupController,
    required this.dropController,
    required this.pickupFocusNode,
    required this.dropFocusNode,
    required this.onLocationTap,
    required this.isGettingLocation,
    this.currentPosition,
    required this.onActiveRideTap,
    required this.searchOpen,
  });

  final TextEditingController pickupController;
  final TextEditingController dropController;
  final FocusNode pickupFocusNode;
  final FocusNode dropFocusNode;
  final VoidCallback onLocationTap;
  final bool isGettingLocation;
  final LatLng? currentPosition;
  final VoidCallback onActiveRideTap;
  final ValueNotifier<bool> searchOpen;

  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> {
  bool _isPickupFocused = false;

  bool get _open =>
      widget.dropFocusNode.hasFocus || widget.pickupFocusNode.hasFocus;

  @override
  void initState() {
    super.initState();
    widget.dropFocusNode.addListener(_onFocusChanged);
    widget.pickupFocusNode.addListener(_onFocusChanged);
    widget.pickupController.addListener(_onPickupTextChanged);
    widget.dropController.addListener(_onDropTextChanged);
  }

  @override
  void dispose() {
    widget.dropFocusNode.removeListener(_onFocusChanged);
    widget.pickupFocusNode.removeListener(_onFocusChanged);
    widget.pickupController.removeListener(_onPickupTextChanged);
    widget.dropController.removeListener(_onDropTextChanged);
    super.dispose();
  }

  /// Results open only while a field has focus: a tap, never programmatic text.
  void _onFocusChanged() {
    if (!mounted) return;
    final open = _open;
    setState(() => _isPickupFocused = widget.pickupFocusNode.hasFocus);
    if (widget.searchOpen.value != open) widget.searchOpen.value = open;
    if (!open) context.read<MapProvider>().clearSuggestions();
  }

  void _onPickupTextChanged() {
    if (!mounted || !widget.pickupFocusNode.hasFocus) return;
    final text = widget.pickupController.text;
    final provider = context.read<MapProvider>();
    if (text.length >= 4 && text != 'Current Location') {
      provider.fetchSuggestions(text);
    } else {
      provider.clearSuggestions();
    }
  }

  void _onDropTextChanged() {
    if (!mounted || !widget.dropFocusNode.hasFocus) return;
    final text = widget.dropController.text;
    final provider = context.read<MapProvider>();
    if (text.length >= 4) {
      provider.fetchSuggestions(text);
    } else {
      provider.clearSuggestions();
    }
  }

  void _close() {
    widget.dropFocusNode.unfocus();
    widget.pickupFocusNode.unfocus();
  }

  Widget _results() {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Divider(height: SgSpace.s4, color: SgColors.line),
            if (_isPickupFocused) _buildCurrentLocationOption(),
            if (mapProvider.isLoadingSuggestions)
              const Padding(
                padding: EdgeInsets.all(SgSpace.s4),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SgColors.gold500,
                    ),
                  ),
                ),
              )
            else
              for (final s in mapProvider.suggestions) _buildSuggestionTile(s),
          ],
        );
      },
    );
  }

  Widget _buildCurrentLocationOption() {
    return InkWell(
      onTap: () {
        if (context.read<MapProvider>().isTripInProgress) {
          _close();
          widget.onActiveRideTap();
          return;
        }
        widget.onLocationTap();
        _close();
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: SgSpace.s3),
              child: Icon(
                Icons.my_location,
                color: SgColors.goldText,
                size: 20,
              ),
            ),
            Text('Current Location', style: SgText.body),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionTile(PlaceSuggestion suggestion) {
    return InkWell(
      onTap: () async {
        final provider = context.read<MapProvider>();

        if (provider.isTripInProgress) {
          _close();
          widget.onActiveRideTap();
          return;
        }

        if (_isPickupFocused) {
          widget.pickupController.text = suggestion.mainText;
          await provider.setPickupLocation(suggestion.placeId);
        } else {
          widget.dropController.text = suggestion.mainText;

          if (provider.pickupLocation == null &&
              widget.currentPosition == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please select pickup location first'),
                backgroundColor: SgColors.gold500,
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }

          if (mounted) {
            context.push('/route-map');
          }

          try {
            await provider.prepareAndCalculateRoute(
              pickupName: widget.pickupController.text.isNotEmpty
                  ? widget.pickupController.text
                  : 'Current Location',
              presetPickup:
                  provider.pickupLocation?.latLng ?? widget.currentPosition,
              dropPlaceId: suggestion.placeId,
            );
          } catch (e) {
            // Pickup outside our service area: show ComingSoonOverlay and stop.
            if (e.toString().contains(
              'Pickup location outside our service area',
            )) {
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => const ComingSoonOverlay(),
                );
              }
              _close();
              return;
            }
            rethrow;
          }
        }

        _close();
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: SgSpace.s2),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: SgSpace.s3),
              child: SgIcon(SgIcons.pin, size: 20),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.mainText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SgText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (suggestion.secondaryText.isNotEmpty)
                    Text(
                      suggestion.secondaryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SgText.caption,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = sgStrings(context);
    final provider = context.watch<MapProvider>();
    // "You are here" only when the pickup really is the device's location.
    final atCurrent =
        provider.pickupLocation?.placeId == 'current' &&
        widget.currentPosition != null &&
        !_isPickupFocused;
    return TapRegion(
      groupId: 'location_search',
      onTapOutside: (_) => _close(),
      child: HomeFromToCard(
        youAreHere: atCurrent ? l.youAreHere : null,
        from: Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.pickupController,
                focusNode: widget.pickupFocusNode,
                style: SgText.body,
                maxLines: 1,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: l.pickupHint,
                  hintStyle: SgText.body.copyWith(color: SgColors.inkSubtle),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (widget.isGettingLocation)
              const Padding(
                padding: EdgeInsets.all(SgSpace.s3),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SgColors.gold500,
                  ),
                ),
              )
            else if (!atCurrent)
              IconButton(
                tooltip: 'Use my location',
                constraints: const BoxConstraints(
                  minWidth: kSgTouch,
                  minHeight: kSgTouch,
                ),
                onPressed: () {
                  if (context.read<MapProvider>().isTripInProgress) {
                    widget.onActiveRideTap();
                    return;
                  }
                  widget.onLocationTap();
                },
                icon: Icon(
                  Icons.my_location,
                  color: SgColors.goldText,
                  size: 20,
                ),
              ),
          ],
        ),
        to: TextField(
          controller: widget.dropController,
          focusNode: widget.dropFocusNode,
          style: SgText.title,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: l.searchDestination,
            hintStyle: SgText.title.copyWith(
              color: SgColors.inkSubtle,
              fontWeight: FontWeight.w600,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        results: _open ? _results() : null,
      ),
    );
  }
}

class _ActiveRideTile extends StatelessWidget {
  const _ActiveRideTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();
    final destination = mapProvider.destinationAddress ?? 'Active Ride';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SgColors.gold500.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SgColors.goldText.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: SgColors.gold500,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_car, color: SgColors.onGold),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Ongoing Ride',
                          style: TextStyle(
                            color: SgColors.goldText,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SgColors.danger,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'LIVE',
                            style: TextStyle(
                              color: SgColors.ink,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: SgColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: SgColors.goldText),
            ],
          ),
        ),
      ),
    );
  }
}
