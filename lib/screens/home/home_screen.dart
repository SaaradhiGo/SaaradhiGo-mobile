import '../../utils/position.dart';
import '../../ui/sg_layout.dart';

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
import '../../core/rider_flags.dart';
import '../../core/maps/sg_map.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../../ui/home_sheet.dart';

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
            SnackBar(
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
                  Text(sgStrings(context).resumingRide),
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
          sgStrings(context).activeRideTitle,
          style: TextStyle(color: SgColors.ink, fontWeight: FontWeight.w600),
        ),
        content: Text(
          sgStrings(context).activeRideBody,
          style: TextStyle(color: SgColors.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              sgStrings(context).dismiss,
              style: TextStyle(color: SgColors.inkMuted),
            ),
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
                fontWeight: FontWeight.w600,
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
            SnackBar(content: Text(sgStrings(context).locationServicesOff)),
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
              SnackBar(content: Text(sgStrings(context).locationDenied)),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sgStrings(context).locationDeniedForever)),
          );
        }
        return;
      }

      final position = await currentOrLastKnownPosition();
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sgStrings(context).locationNotFound)),
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
        String addressText = sgStrings(context).currentLocation;
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
      _ProfileTab(
        onWallet: () => setState(() => _tabIndex = 2),
        onTrips: () => setState(() => _tabIndex = 1),
        onBack: () => setState(() => _tabIndex = 0),
      ),
    ];

    return PopScope(
      // Back from History, Wallet or Profile returns home.
      canPop: _tabIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tabIndex = _tabIndex == 2 ? 3 : 0);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: SgColors.bg000,
        drawer: _MenuDrawer(
          onTab: (index) => setState(() => _tabIndex = index),
        ),
        // No tab bar (signed-in design rider-app-home): the map's menu
        // button opens the drawer, and Trips, Wallet and Account each carry
        // a back button.
        body: switch (_tabIndex) {
          0 => tabs[0],
          3 => SafeArea(child: tabs[3]),
          _ => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    key: const Key('page_back'),
                    tooltip: 'Back',
                    constraints: const BoxConstraints(
                      minWidth: kSgTouch,
                      minHeight: kSgTouch,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        setState(() => _tabIndex = _tabIndex == 2 ? 3 : 0),
                    icon: SgIcon(SgIcons.back, size: 24, color: SgColors.ink),
                  ),
                  Expanded(child: tabs[_tabIndex]),
                ],
              ),
            ),
          ),
        },
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
              sgStrings(context).yourRides,
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
              sgStrings(context).paymentMethods,
              () => context.push('/payment-methods'),
            ),
            row(
              SgIcons.bell,
              sgStrings(context).notifications,
              () => context.push('/notifications'),
              count: unread,
            ),
            if (MarketConfigStore.instance.current.referralsAvailable)
              row(
                kGiftIcon,
                sgStrings(context).referFriend,
                () => context.push('/refer'),
              ),
            row(
              SgIcons.user,
              sgStrings(context).tabAccount,
              () => onTab(3),
              key: const Key('menu_profile'),
            ),
            row(
              SgIcons.lock,
              sgStrings(context).privacySecurity,
              () => context.push('/privacy-security'),
            ),
            row(
              SgIcons.help,
              sgStrings(context).helpSupport,
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
        SnackBar(
          content: Text(sgStrings(context).selectPickupFirst),
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
            : sgStrings(context).currentLocation,
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
    final l = sgStrings(context);
    final here = mapProvider.pickupLocation?.latLng ?? currentPosition;
    final near = homePlaceFilter(marketOf(context), here);
    void open(double lat, double lng, String name) =>
        _goTo(context, '$lat,$lng', dropName: name);

    // Saved places from GET /rider/locations/all/, with Home/Work from the
    // place's own `label`.
    final chips = <SavedChipData>[
      for (final f in mapProvider.favoriteLocations.take(4))
        if (f.latitude != 0 || f.longitude != 0)
          SavedChipData(
            label: savedPlaceLabel(l, f),
            icon: switch (RiderFlags.homeWorkLabels ? f.label : null) {
              'home' => SgIcons.home,
              'work' => SgIcons.work,
              _ => SgIcons.pin,
            },
            onTap: () => open(f.latitude, f.longitude, f.addressText),
          ),
    ];
    // Recent drops from the rider's own trips, nearest first in time.
    final seen = <String>{};
    final recents = <RecentPlaceData>[];
    for (final t in mapProvider.recentLocations) {
      final lat = t.destinationLat, lng = t.destinationLng;
      final addr = t.destinationAddress.trim();
      if (recents.length >= 3 || lat == null || lng == null || addr.isEmpty) {
        continue;
      }
      if (near != null && !near(LatLng(lat, lng))) continue;
      if (!seen.add(addr.toLowerCase())) continue;
      final p = splitPlace(addr);
      recents.add(
        RecentPlaceData(
          name: p.name,
          address: p.address,
          onTap: () => open(lat, lng, addr),
        ),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: searchOpen,
      builder: (context, open, _) => PopScope(
        canPop: !open,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          pickupFocusNode.unfocus();
          dropFocusNode.unfocus();
        },
        child: LayoutBuilder(
          builder: (context, box) {
            final top = MediaQuery.paddingOf(context).top;
            final sheetMax = box.maxHeight * 0.55;
            return Stack(
              children: [
                Positioned.fill(
                  child: _HomeMap(here: here, bottomInset: sheetMax - 24),
                ),
                Positioned(
                  top: top + SgSpace.s4,
                  left: SgSpace.s4,
                  child: SgMapButton(
                    key: const Key('home_menu'),
                    icon: SgIcons.menu,
                    label: l.menu,
                    onTap: onMenuTap,
                  ),
                ),
                Positioned(
                  key: const ValueKey('home-sheet'),
                  left: 0,
                  right: 0,
                  bottom: 0,
                  top: open ? top + SgSpace.s2 : null,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: open ? double.infinity : sheetMax,
                    ),
                    child: SgReadableWidth(
                      child: HomeSheet(
                        expanded: open,
                        loading: mapProvider.isLoadingHomeData,
                        failed: mapProvider.homeDataFailed,
                        onRetry: mapProvider.fetchDynamicHomeData,
                        banner: mapProvider.isTripInProgress
                            ? _ActiveRideTile(onTap: onActiveRideTap)
                            : null,
                        chips: chips,
                        recents: recents,
                        search: _LocationCard(
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
                    ),
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

/// A saved place's chip label: Home/Work when labels are on and the server
/// sent one, else the first part of the address.
String savedPlaceLabel(AppLocalizations l, FavoriteLocation f) {
  if (RiderFlags.homeWorkLabels && f.label == 'home') return l.navHome;
  if (RiderFlags.homeWorkLabels && f.label == 'work') return l.savedWork;
  return splitPlace(f.addressText).name;
}

/// The map behind the home sheet: the rider's position, centred when known.
class _HomeMap extends StatefulWidget {
  const _HomeMap({required this.here, required this.bottomInset});

  final LatLng? here;
  final double bottomInset;

  @override
  State<_HomeMap> createState() => _HomeMapState();
}

class _HomeMapState extends State<_HomeMap> {
  SgMapController? _map;

  @override
  void didUpdateWidget(covariant _HomeMap old) {
    super.didUpdateWidget(old);
    final here = widget.here;
    if (here != null && here != old.here) _map?.moveTo(here);
  }

  @override
  Widget build(BuildContext context) {
    final here = widget.here;
    return SgMap(
      initialCenter:
          here ??
          marketOf(context).cities.firstOrNull?.center ??
          const LatLng(17.385044, 78.4867),
      initialZoom: 15,
      padding: EdgeInsets.only(bottom: widget.bottomInset),
      markers: [
        if (here != null)
          SgMarker(
            id: 'here',
            point: here,
            icon: sgPickupIcon,
            anchor: sgJourneyAnchor,
          ),
      ],
      onMapCreated: (c) {
        _map = c;
        final h = widget.here;
        if (h != null) c.moveTo(h);
      },
    );
  }
}

// History screen is now a separate component

// Wallet screen is now a separate component

// Profile tab implementation

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.onWallet,
    required this.onTrips,
    required this.onBack,
  });

  final VoidCallback onWallet;
  final VoidCallback onTrips;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final map = context.watch<MapProvider>();
    final saved = map.favoriteLocations;
    final l = sgStrings(context);
    final a = SgAppearance.instance;
    final names = [for (final f in saved.take(2)) savedPlaceLabel(l, f)];
    return AccountView(
      title: l.tabAccount,
      name: auth.fullName,
      phoneLine: maskedPhone(auth.countryCode, auth.phoneNumber),
      avatarUrl: auth.avatarUrl,
      onBack: onBack,
      onHeader: () => context.push('/personal-info'),
      rows: [
        AccountRowData(
          key: const Key('account_trips'),
          icon: kListIcon,
          label: l.accountYourTrips,
          subtitle: l.accountTripsHint,
          onTap: onTrips,
        ),
        AccountRowData(
          key: const Key('account_saved'),
          icon: SgIcons.home,
          label: l.accountSavedPlaces,
          subtitle: names.isEmpty ? null : names.join(', '),
          onTap: () => _showSavedPlaces(context, saved),
        ),
        AccountRowData(
          key: const Key('profile_wallet'),
          icon: kCardIcon,
          label: l.accountPayment,
          // The method the booking flow will use (Cash, Wallet, Online).
          subtitle: paymentMethodLabel(l, map.selectedPaymentMethod),
          onTap: () => context.push('/payment-methods'),
        ),
        // Safety ("2 trusted contacts") waits for a trusted-contacts API.
        if (RiderFlags.trustedContacts)
          AccountRowData(
            key: const Key('account_safety'),
            icon: SgIcons.shield,
            label: l.safety,
            onTap: () {},
          ),
        AccountRowData(
          key: const Key('profile_language'),
          icon: SgIcons.language,
          label: l.language,
          subtitle: languageLabel(l, a.language),
          onTap: () => showLanguagePicker(context),
        ),
        AccountRowData(
          key: const Key('profile_appearance'),
          icon: SgIcons.moon,
          label: l.accountTheme,
          subtitle: themeChoiceLabel(l, a.theme),
          onTap: () => showThemePicker(context),
        ),
        // Only while a referral offer is live for riders in this market.
        if (MarketConfigStore.instance.current.referralsAvailable)
          AccountRowData(
            key: const Key('account_refer'),
            icon: kGiftIcon,
            label: l.referFriend,
            onTap: () => context.push('/refer'),
          ),
        AccountRowData(
          key: const Key('account_help'),
          icon: SgIcons.help,
          label: l.accountHelp,
          onTap: () => context.push('/help-support'),
        ),
      ],
      signOutLabel: l.accountSignOut,
      onSignOut: () async {
        await context.read<AuthProvider>().logout();
        if (!context.mounted) return;
        context.go('/login');
      },
      deleteLabel: l.accountDelete,
      onDelete: () => _confirmDelete(context),
    );
  }

  void _showSavedPlaces(BuildContext context, List<FavoriteLocation> saved) {
    final l = sgStrings(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SgSheetSurface(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.accountSavedPlaces, style: SgText.title),
              const SizedBox(height: SgSpace.s3),
              if (saved.isEmpty)
                Text(l.accountNoSavedPlaces, style: SgText.caption)
              else
                for (final f in saved)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: SgSpace.s2),
                    child: Text(f.addressText, style: SgText.body),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l = sgStrings(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: SgColors.bg100,
        title: Text(l.deleteAccountTitle, style: SgText.title),
        content: Text(l.deleteAccountBody, style: SgText.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.cancel, style: SgText.body),
          ),
          TextButton(
            key: const Key('account_delete_confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              l.deleteAccountConfirm,
              style: SgText.body.copyWith(
                color: SgColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    final ok = await ApiService().deleteMyAccount();
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.deleteAccountFailed)));
      return;
    }
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    context.go('/login');
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
    if (text.length >= 4 && text != sgStrings(context).currentLocation) {
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
              Padding(
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
            Text(sgStrings(context).currentLocation, style: SgText.body),
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
              SnackBar(
                content: Text(sgStrings(context).selectPickupFirst),
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
                  : sgStrings(context).currentLocation,
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
                    style: SgText.body.copyWith(fontWeight: FontWeight.w600),
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
              Padding(
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
                tooltip: sgStrings(context).useMyLocation,
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
        compact: !_open,
        to: TextField(
          controller: widget.dropController,
          focusNode: widget.dropFocusNode,
          style: SgText.body,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: l.searchADestination,
            hintStyle: SgText.body.copyWith(color: SgColors.inkMuted),
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
    final destination =
        mapProvider.destinationAddress ?? sgStrings(context).activeRideTitle;

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
                decoration: BoxDecoration(
                  color: SgColors.gold500,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.directions_car, color: SgColors.onGold),
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
                            fontSize: SgText.sizeSmall,
                            fontWeight: FontWeight.w600,
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
                              fontSize: SgText.sizeSmall,
                              fontWeight: FontWeight.w600,
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
                        fontSize: SgText.sizeBody,
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
