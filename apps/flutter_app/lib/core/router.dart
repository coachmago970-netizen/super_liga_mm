import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../admin/admin_pages.dart";
import "../auth/auth_pages.dart";
import "../auth/auth_providers.dart";
import "../call/call_pages.dart";
import "../chat/chat_page.dart";
import "../home/home_pages.dart";
import "../invites/invite_page.dart";
import "../members/members_online_page.dart";
import "../screen_share/screen_share_page.dart";
import "../settings/settings_pages.dart";

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(currentSessionProvider);
  const publicRoutes = <String>{
    "/splash",
    "/welcome",
    "/login",
    "/register",
    "/forgot-password",
    "/email-confirmation",
    "/invite"
  };

  return GoRouter(
    initialLocation: "/splash",
    redirect: (_, state) {
      final currentPath = state.matchedLocation;
      final isPublic = publicRoutes.contains(currentPath) || currentPath.startsWith("/invite/");

      if (session == null && !isPublic) return "/welcome";
      if (session != null &&
          (currentPath == "/splash" ||
              currentPath == "/welcome" ||
              currentPath == "/login" ||
              currentPath == "/register")) {
        return "/server";
      }
      return null;
    },
    routes: [
      GoRoute(path: "/splash", builder: (_, __) => const SplashPage()),
      GoRoute(path: "/welcome", builder: (_, __) => const WelcomePage()),
      GoRoute(path: "/login", builder: (_, __) => const LoginPage()),
      GoRoute(path: "/register", builder: (_, __) => const RegisterPage()),
      GoRoute(path: "/forgot-password", builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(path: "/email-confirmation", builder: (_, __) => const EmailConfirmationPage()),
      GoRoute(path: "/invite", builder: (_, __) => const InviteEntryPage()),
      GoRoute(
        path: "/invite/:code",
        builder: (_, state) => InviteEntryPage(initialCode: state.pathParameters["code"])
      ),
      GoRoute(path: "/server", builder: (_, __) => const ServerHomePage()),
      GoRoute(path: "/chat/geral", builder: (_, __) => const GeneralChatPage()),
      GoRoute(path: "/voice-channel", builder: (_, __) => const VoiceChannelPage()),
      GoRoute(path: "/call", builder: (_, __) => const CallPage()),
      GoRoute(path: "/screen-share", builder: (_, __) => const ScreenSharePage()),
      GoRoute(path: "/members-online", builder: (_, __) => const MembersOnlinePage()),
      GoRoute(path: "/profile", builder: (_, __) => const ProfilePage()),
      GoRoute(path: "/settings", builder: (_, __) => const SettingsPage()),
      GoRoute(path: "/admin", builder: (_, __) => const AdminPanelPage()),
      GoRoute(path: "/admin/invites", builder: (_, __) => const ManageInvitesPage()),
      GoRoute(path: "/admin/members", builder: (_, __) => const ManageMembersPage()),
      GoRoute(path: "/admin/logs", builder: (_, __) => const AdminLogsPage()),
      GoRoute(path: "/access-denied", builder: (_, __) => const AccessDeniedPage())
    ]
  );
});
