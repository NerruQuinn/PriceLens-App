import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/skin_theme_resolver.dart';
import 'presentation/screens/main_wrapper.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/scan/camera_screen.dart';
import 'presentation/screens/result/price_result_screen.dart';
import 'presentation/screens/basket/basket_estimator_screen.dart';
import 'presentation/screens/submit/price_submission_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/shop/skin_shop_screen.dart';
import 'presentation/screens/explore/explore_screen.dart';
import 'presentation/screens/history/search_history_screen.dart';
import 'presentation/screens/community/community_screen.dart';

import 'providers/auth_provider.dart';
import 'providers/skin_provider.dart';
import 'data/services/skin_seed_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  try {
    await SkinSeedService.forceSeedSkins();
  } catch (e) {
    debugPrint('Error initializing skins: $e');
  }

  FirebaseFirestore.instance.collection('skins').get().then((snapshot) {
    for (var doc in snapshot.docs) {
      debugPrint('[SkinDebug] ID: ${doc.id}, name: ${doc.data()['name']}');
    }
  });
  
  runApp(const ProviderScope(child: MyApp()));
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuth = authState.valueOrNull != null;
      final isSplash = state.matchedLocation == '/splash';
      final isLogin = state.matchedLocation == '/login';
      
      if (authState.isLoading) return null;

      if (isSplash) {
        return isAuth ? '/home' : '/login';
      }

      if (!isAuth && !isLogin && !isSplash) {
        return '/login';
      }

      if (isAuth && isLogin) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainWrapper(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/basket',
                builder: (context, state) => const BasketEstimatorScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const CameraScreen(),
      ),
      GoRoute(
        path: '/result',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return PriceResultScreen(extra: extra);
        },
      ),
      GoRoute(
        path: '/submit',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return PriceSubmissionScreen(extra: extra);
        },
      ),
      GoRoute(
        path: '/shop',
        builder: (context, state) => const SkinShopScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const SearchHistoryScreen(),
      ),
      GoRoute(
        path: '/community',
        builder: (context, state) => const CommunityScreen(),
      ),
    ],
  );
});

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  const ResponsiveWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    double maxWidth;
    if (width > 1024) {
      maxWidth = 430; // desktop
    } else if (width > 600) {
      maxWidth = 600; // tablet
    } else {
      maxWidth = double.infinity; // mobile full width
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE8EAF6),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final currentSkin = ref.watch(activeSkinProvider).value ?? 'default';

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final baseTheme = AppTheme.getTheme(lightDynamic, Brightness.light);
        final baseDarkTheme = AppTheme.getTheme(darkDynamic, Brightness.dark);

        return MaterialApp.router(
          title: 'PriceLens ID',
          theme: SkinThemeResolver.resolveTheme(currentSkin, baseTheme),
          darkTheme: SkinThemeResolver.resolveTheme(currentSkin, baseDarkTheme),
          themeMode: ThemeMode.system,
          routerConfig: router,
          builder: (context, child) {
            return ResponsiveWrapper(child: child ?? const SizedBox());
          },
        );
      },
    );
  }
}
