import '../../utils/position.dart';
import 'dart:ui';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/notification_provider.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/maps/sg_map.dart';
import '../../core/market/market_config_store.dart';
import '../../ui/home_sheet.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late int _tabIndex;
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
                      color: Color(0xFFEEBD2B),
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
        backgroundColor: const Color(0xFF1E1C18),
        title: Text(
          'Active Ride',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'You already have an active ride request or trip. Would you like to view it?',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Dismiss',
              style: GoogleFonts.inter(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkAndRedirectActiveRide();
            },
            child: Text(
              'View Ride',
              style: GoogleFonts.inter(
                color: const Color(0xFFEEBD2B),
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
      ),
      const HistoryScreen(),
      const WalletScreen(),
      const _ProfileTab(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: SgColors.bg000,
      drawer: _MenuDrawer(
        onTab: (index) => setState(() => _tabIndex = index),
      ),
      body: Stack(
        children: [
          if (_tabIndex == 0)
            Positioned.fill(child: tabs[0])
          else
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 85),
                child: tabs[_tabIndex],
              ),
            ),
          _BottomNav(
            selectedIndex: _tabIndex,
            onItemTap: (index) {
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() => _tabIndex = index);
            },
          ),
        ],
      ),
    );
  }
}

/// The menu: the tabs and the places the old header bell and profile led to.
class _MenuDrawer extends StatelessWidget {
  const _MenuDrawer({required this.onTab});

  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    Widget item(String icon, String label, VoidCallback onTap, {int badge = 0}) {
      return ListTile(
        minTileHeight: kSgTouch,
        leading: SgIcon(icon, size: 22, color: SgColors.goldText),
        title: Text(label, style: SgText.body),
        trailing: badge > 0 ? Text('$badge', style: SgText.caption) : null,
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
      );
    }

    final unread = context.watch<NotificationProvider>().unreadCount;
    return Drawer(
      backgroundColor: SgColors.bg100,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: SgSpace.s4),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(SgSpace.s5, 0, SgSpace.s5, SgSpace.s4),
              child: Text('SaaradhiGo', style: SgText.title),
            ),
            item(SgIcons.home, 'Home', () => onTab(0)),
            item(SgIcons.history, 'Your rides', () => onTab(1)),
            item(SgIcons.wallet, 'Wallet', () => onTab(2)),
            item(SgIcons.bell, 'Notifications', () => context.push('/notifications'),
                badge: unread),
            item(SgIcons.user, 'Profile', () => onTab(3)),
            item(SgIcons.help, 'Help and support', () => context.push('/help-support')),
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

  /// Height of the bottom navigation the sheet sits above.
  static const double _navHeight = 84;

  Future<void> _goTo(BuildContext context, String dropPlaceId) async {
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
          backgroundColor: Color(0xFFEEBD2B),
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
    final favorites = mapProvider.favoriteLocations;
    final recents = mapProvider.recentLocations;
    final market = marketOf(context);
    final here = mapProvider.pickupLocation?.latLng ?? currentPosition;

    final chips = <SavedChipData>[
      for (final fav in favorites.take(3))
        SavedChipData(
          label: splitPlace(fav.addressText).name,
          icon: _chipIcon(fav.addressText),
          onTap: () => _goTo(
            context,
            fav.latitude != 0 ? '${fav.latitude},${fav.longitude}' : 'current',
          ),
          // Removing a saved place stays one long-press away.
          onLongPress: () => context.read<MapProvider>().deleteLocation(fav.id),
        ),
    ];

    final places = <RecentPlaceData>[
      for (final trip in recents)
        RecentPlaceData(
          name: splitPlace(trip.destinationAddress).name,
          address: splitPlace(trip.destinationAddress).address,
          distance: (here != null &&
                  trip.destinationLat != null &&
                  trip.destinationLng != null)
              ? market.formatDistanceKm(
                  const Distance().as(
                    LengthUnit.Kilometer,
                    here,
                    LatLng(trip.destinationLat!, trip.destinationLng!),
                  ).toDouble(),
                )
              : null,
          onTap: () async {
            final provider = context.read<MapProvider>();
            if (trip.destinationLat != null && trip.destinationLng != null) {
              await _goTo(
                context,
                '${trip.destinationLat},${trip.destinationLng}',
              );
            } else if (!provider.isTripInProgress) {
              context.push('/route-map');
              provider.fetchSuggestions(trip.destinationAddress);
            } else {
              onActiveRideTap();
            }
          },
          // Saving a recent place stays one long-press away.
          onLongPress: () {
            if (trip.destinationLat != null && trip.destinationLng != null) {
              context.read<MapProvider>().saveLocation(
                trip.destinationAddress,
                trip.destinationLat!,
                trip.destinationLng!,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Location saved to favorites')),
              );
            }
          },
        ),
    ];

    final media = MediaQuery.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: SgMap(
            initialCenter: here ?? const LatLng(17.385044, 78.4867),
            interactive: false,
            markers: [
              if (here != null)
                SgMarker(
                  id: 'pickup',
                  point: here,
                  icon: const SgSvgMarker('assets/markers/pickup.svg'),
                  label: 'Pickup',
                ),
            ],
          ),
        ),
        Positioned(
          top: media.padding.top + SgSpace.s2,
          left: SgSpace.s4,
          right: SgSpace.s4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SgMapButton(icon: SgIcons.menu, label: 'Menu', onTap: onMenuTap),
              Container(
                width: kSgTouch,
                height: kSgTouch,
                decoration: BoxDecoration(
                  color: SgColors.bg000,
                  shape: BoxShape.circle,
                  border: Border.all(color: SgColors.goldLine),
                ),
                padding: const EdgeInsets.all(10),
                child: SvgPicture.asset('assets/brand/saaradhigo-emblem-gold.svg'),
              ),
              SgMapButton(icon: SgIcons.user, label: 'Account', onTap: onProfileTap),
            ],
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: _navHeight + media.padding.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: media.size.height * 0.62),
              child: HomeSheet(
                greeting: greetingFor(DateTime.now()),
                loading: mapProvider.isLoadingHomeData,
                banner: mapProvider.isTripInProgress
                    ? _ActiveRideTile(onTap: onActiveRideTap)
                    : null,
                search: _LocationCard(
                  pickupController: pickupController,
                  dropController: dropController,
                  pickupFocusNode: pickupFocusNode,
                  dropFocusNode: dropFocusNode,
                  onLocationTap: onLocationTap,
                  isGettingLocation: isGettingLocation,
                  currentPosition: currentPosition,
                  onActiveRideTap: onActiveRideTap,
                ),
                chips: chips,
                recents: places,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String? _chipIcon(String address) {
    final first = splitPlace(address).name.toLowerCase();
    if (first == 'home') return SgIcons.home;
    if (first == 'work' || first == 'office') return SgIcons.work;
    return null;
  }
}

// History screen is now a separate component

// Wallet screen is now a separate component

// Profile tab implementation

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  static const String _fallbackName = 'John Doe';
  static const String _fallbackRating = '4.98';
  static const String _fallbackAvatarUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAPKZPGwmJqpCAihXSwtX1NVoImyBkmHzRpQ-VAOuMNCg1NdDM1Y5z1do2yqtE65Qal8OTMrMZednPquFBXo2pxr8NkTMmVDfafUMbVqlrJyooB_iaOuuthn_amKR15p3JWbeC17NBHKxjjTU4nZ3NU_L4DzcY5k1GbTVLX_ylAcrXRisGB6uoEAnuSpO8BJ-JJGe-Ogqdo_EKr7tMfCMRn22AmRjgpGPqbxrGZX-u_F5Y28uaFp0zNckZKrsJfwfzF_QET1MyTl1c';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final displayName = (auth.fullName?.trim().isNotEmpty ?? false)
        ? auth.fullName!.trim()
        : _fallbackName;
    final displayRating = (auth.rating?.trim().isNotEmpty ?? false)
        ? auth.rating!.trim()
        : _fallbackRating;
    final displayAvatar = (auth.avatarUrl?.trim().isNotEmpty ?? false)
        ? auth.avatarUrl!.trim()
        : _fallbackAvatarUrl;

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _ProfileHeader(),
          const SizedBox(height: 24),
          const Text(
            'Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w600,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 24),
          Center(child: _ProfileAvatar(imageUrl: displayAvatar)),
          const SizedBox(height: 16),
          Center(
            child: Text(
              displayName,
              style: GoogleFonts.inter(
                color: const Color(0xFFF8FAFC),
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayRating,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEEBD2B),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFEEBD2B),
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _ProfileMenuTile(
            icon: Icons.person,
            title: 'Personal Information',
            onTap: () => context.push('/personal-info'),
          ),
          const SizedBox(height: 8),
          _ProfileMenuTile(
            icon: Icons.credit_card,
            title: 'Payment Methods',
            onTap: () => context.push('/payment-methods'),
          ),
          const SizedBox(height: 8),
          _ProfileMenuTile(
            icon: Icons.lock,
            title: 'Privacy & Security',
            onTap: () => context.push('/privacy-security'),
          ),
          const SizedBox(height: 8),
          _ProfileMenuTile(
            icon: Icons.help,
            title: 'Help & Support',
            onTap: () => context.push('/help-support'),
          ),
          const SizedBox(height: 8),
          // Hidden unless a referral offer is live for riders in this market.
          ListenableBuilder(
            listenable: MarketConfigStore.instance,
            builder: (context, _) =>
                MarketConfigStore.instance.current.referralsAvailable
                ? _ProfileMenuTile(
                    icon: Icons.sell,
                    title: 'Refer & Earn',
                    onTap: () => context.push('/refer'),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 26),
          OutlinedButton(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              context.go('/login');
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF211D18),
              foregroundColor: const Color(0xFFF87171),
              side: const BorderSide(color: Color(0x33EF4444)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: Text(
              'Log Out',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'SaaradhiGo',
            style: TextStyle(
              color: Color(0xFFEEBD2B),
              fontSize: 23,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.6,
            ),
          ),
        ),
        Consumer<NotificationProvider>(
          builder: (context, provider, child) => GestureDetector(
            onTap: () => context.push('/notifications'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 3),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0x14FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications,
                      color: Color(0xFFE2E8F0),
                      size: 21,
                    ),
                  ),
                ),
                if (provider.unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${provider.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      height: 116,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFEEBD2B),
        boxShadow: [
          BoxShadow(color: Color(0x99EEBD2B), blurRadius: 22, spreadRadius: 1),
        ],
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          memCacheWidth: 200,
          memCacheHeight: 200,
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (context, url) => Container(
            color: const Color(0xFF24211C),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFEEBD2B),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: const Color(0xFF24211C),
            child: const Icon(Icons.person, size: 56, color: Color(0xFFCBD5E1)),
          ),
        ),
      ),
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
  });

  final TextEditingController pickupController;
  final TextEditingController dropController;
  final FocusNode pickupFocusNode;
  final FocusNode dropFocusNode;
  final VoidCallback onLocationTap;
  final bool isGettingLocation;
  final LatLng? currentPosition;
  final VoidCallback onActiveRideTap;

  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isSearching = false;
  bool _isPickupFocused = false;

  @override
  void initState() {
    super.initState();
    widget.dropFocusNode.addListener(() {
      if (!mounted) return;
      if (widget.dropFocusNode.hasFocus) {
        setState(() => _isPickupFocused = false);
        if (widget.dropController.text.length >= 4) {
          _showOverlay();
        } else {
          _hideOverlay();
        }
      }
    });

    widget.pickupFocusNode.addListener(() {
      if (!mounted) return;
      if (widget.pickupFocusNode.hasFocus) {
        setState(() => _isPickupFocused = true);
        // Only show overlay on focus if empty (to suggest Current Loc) or already has search text
        final text = widget.pickupController.text;
        if (text.isEmpty || (text.length >= 4 && text != 'Current Location')) {
          _showOverlay();
        } else {
          _hideOverlay();
        }
      }
    });

    widget.pickupController.addListener(_onPickupSearchChanged);
    widget.dropController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.pickupController.removeListener(_onPickupSearchChanged);
    widget.dropController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onPickupSearchChanged() {
    final text = widget.pickupController.text;

    // Safety check for user-defined threshold and specific strings
    if (text == 'Current Location' || text.isEmpty) {
      if (text.isEmpty && widget.pickupFocusNode.hasFocus) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
      return;
    }

    if (text.length >= 4) {
      context.read<MapProvider>().fetchSuggestions(text);
      if (!_isSearching) {
        setState(() {
          _isSearching = true;
          _isPickupFocused = true;
        });
        _showOverlay();
      }
    } else {
      context.read<MapProvider>().clearSuggestions();
      if (_isSearching && _isPickupFocused) {
        // If we were searching and now deleted below 4 chars,
        // hide unless it's empty (which is handled above)
        setState(() => _isSearching = false);
        _hideOverlay();
      }
    }
  }

  void _onSearchChanged() {
    final text = widget.dropController.text;
    if (text.length >= 4) {
      context.read<MapProvider>().fetchSuggestions(text);
      if (!_isSearching) {
        setState(() {
          _isSearching = true;
          _isPickupFocused = false;
        });
        _showOverlay();
      }
    } else {
      context.read<MapProvider>().clearSuggestions();
      if (_isSearching && !_isPickupFocused) {
        setState(() => _isSearching = false);
        _hideOverlay();
      }
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.bottomLeft,
        offset: const Offset(0.0, -8),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: SizedBox(
            width: size.width,
            child: TapRegion(
              groupId: 'location_search',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: DefaultTextStyle(
                  style: const TextStyle(decoration: TextDecoration.none),
                  child: _buildSuggestionsList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildSuggestionsList() {
    return Material(
      color: Colors.transparent,
      child: Consumer<MapProvider>(
        builder: (context, mapProvider, child) {
          if (mapProvider.isLoadingSuggestions) {
            return _buildOverlayContainer(
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFEEBD2B)),
                ),
              ),
            );
          }

          if (mapProvider.suggestions.isEmpty &&
              (!_isPickupFocused || widget.pickupController.text.isNotEmpty)) {
            return const SizedBox.shrink();
          }

          return _buildOverlayContainer(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isPickupFocused) _buildCurrentLocationOption(),
                  if (mapProvider.suggestions.isNotEmpty)
                    ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: mapProvider.suggestions.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: Color(0x1AFFFFFF)),
                      itemBuilder: (context, index) {
                        final suggestion = mapProvider.suggestions[index];
                        return _buildSuggestionTile(suggestion);
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentLocationOption() {
    return ListTile(
      leading: const Icon(Icons.my_location, color: Color(0xFFEEBD2B)),
      title: const Text(
        'Current Location',
        style: TextStyle(color: Colors.white),
      ),
      onTap: () {
        if (context.read<MapProvider>().isTripInProgress) {
          _hideOverlay();
          widget.onActiveRideTap();
          return;
        }
        widget.onLocationTap();
        _hideOverlay();
        setState(() => _isSearching = false);
      },
    );
  }

  Widget _buildSuggestionTile(PlaceSuggestion suggestion) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final provider = context.read<MapProvider>();

        if (provider.isTripInProgress) {
          _hideOverlay();
          widget.onActiveRideTap();
          return;
        }

        if (_isPickupFocused) {
          widget.pickupController.text = suggestion.mainText;
          await provider.setPickupLocation(suggestion.placeId);
        } else {
          widget.dropController.text = suggestion.mainText;
          widget.dropFocusNode.unfocus();

          if (provider.pickupLocation == null &&
              widget.currentPosition == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please select pickup location first'),
                backgroundColor: Color(0xFFEEBD2B),
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
            // Check if error is due to pickup location outside our service area
            if (e.toString().contains(
              'Pickup location outside our service area',
            )) {
              // Show ComingSoonOverlay
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => const ComingSoonOverlay(),
                );
              }
              _hideOverlay();
              return; // Don't proceed with route calculation
            }
            // Re-throw other errors
            rethrow;
          }
        }

        _hideOverlay();
        setState(() => _isSearching = false);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFF94A3B8)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.mainText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion.secondaryText,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayContainer({required Widget child}) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: SgColors.bg200,
        borderRadius: BorderRadius.circular(SgRadius.md),
        border: Border.all(color: SgColors.goldLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: 'location_search',
      onTapOutside: (_) {
        widget.dropFocusNode.unfocus();
        if (mounted) _hideOverlay();
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: kSgTouch,
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: SgSpace.s2),
                    decoration: const BoxDecoration(
                      color: SgColors.pickup,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: SgSpace.s2),
                  Expanded(
                    child: TextField(
                      controller: widget.pickupController,
                      focusNode: widget.pickupFocusNode,
                      style: SgText.body,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Enter pickup point',
                        hintStyle: SgText.body.copyWith(color: SgColors.inkSubtle),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  widget.isGettingLocation
                      ? const Padding(
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
                      : IconButton(
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
                          icon: const Icon(
                            Icons.my_location,
                            color: SgColors.goldText,
                            size: 20,
                          ),
                        ),
                ],
              ),
            ),
            SgSearchBar(
              field: TextField(
                controller: widget.dropController,
                focusNode: widget.dropFocusNode,
                style: SgText.body,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search destination',
                  hintStyle: SgText.body.copyWith(color: SgColors.inkSubtle),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF24211C), Color(0xFF221F1A)],
          ),
          border: Border.all(color: const Color(0x1AFFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF94A3B8), size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: const Color(0xFFE2E8F0),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF64748B), size: 24),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onItemTap});

  final int selectedIndex;
  final ValueChanged<int> onItemTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 84,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            decoration: const BoxDecoration(
              color: Color(0xE61A1814),
              border: Border(top: BorderSide(color: Color(0x0DFFFFFF))),
            ),
            child: Row(
              children: [
                _NavItem(
                  key: const Key('home-nav-home'),
                  icon: Icons.home,
                  label: 'Home',
                  selected: selectedIndex == 0,
                  onTap: () => onItemTap(0),
                ),
                _NavItem(
                  key: const Key('home-nav-history'),
                  icon: Icons.history,
                  label: 'History',
                  selected: selectedIndex == 1,
                  glowWhenSelected: true,
                  onTap: () => onItemTap(1),
                ),
                _NavItem(
                  key: const Key('home-nav-wallet'),
                  icon: Icons.account_balance_wallet,
                  label: 'Wallet',
                  selected: selectedIndex == 2,
                  glowWhenSelected: true,
                  onTap: () => onItemTap(2),
                ),
                _NavItem(
                  key: const Key('home-nav-profile'),
                  icon: Icons.person,
                  label: 'Profile',
                  selected: selectedIndex == 3,
                  glowWhenSelected: true,
                  onTap: () => onItemTap(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    this.glowWhenSelected = false,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool glowWhenSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color itemColor = selected
        ? const Color(0xFFEEBD2B)
        : const Color(0xFF94A3B8);
    final List<Shadow>? shadows = selected && glowWhenSelected
        ? const [Shadow(color: Color(0x80EEBD2B), blurRadius: 8)]
        : null;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: itemColor, size: 24, shadows: shadows),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: itemColor,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                shadows: shadows,
              ),
            ),
          ],
        ),
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
            color: const Color(0xFFEEBD2B).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFEEBD2B).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEBD2B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: Color(0xFF1A1814),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Ongoing Ride',
                          style: TextStyle(
                            color: Color(0xFFEEBD2B),
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
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFEEBD2B)),
            ],
          ),
        ),
      ),
    );
  }
}
