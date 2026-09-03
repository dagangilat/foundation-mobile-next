package com.rarilabs.rarime.util

sealed class Screen(val route: String) {
    data object Intro : Screen("intro")
    data object ScanPassport : Screen("scan_passport") {
        data object ScanPassportSpecific : Screen("scan_passport_specific")
        data object ScanPassportPoints : Screen("scan_passport_points")
    }

    data object Lock : Screen("lock")

    data object Register : Screen("register") {
        data object NewIdentity : Screen("new_identity")
        data object ImportIdentity : Screen("import_identity")
    }

    data object Passcode : Screen("security") {
        data object EnablePasscode : Screen("enable_passcode")
        data object AddPasscode : Screen("add_passcode")
    }

    data object Loading : Screen("loading")

    data object Maintenance : Screen("maintenance")

    data object LoadFailed : Screen("load_failed")

    data object EnableBiometrics : Screen("enable_biometrics")

    data object NotificationsList : Screen("notifications_list")

    data object Main : Screen("main") {
        data object Home : Screen("home")

        data object DebugIdentity : Screen("identity_debug")

        data object Identity : Screen("identity")
        data object QrScan : Screen("qr_scan")

        data object Profile : Screen("profile") {
            data object AuthMethod : Screen("auth_method")
            data object ExportKeys : Screen("export_keys")
            data object Language : Screen("language")
            data object Theme : Screen("theme")
            data object AppIcon : Screen("app_icon")
            data object Terms : Screen("terms")
            data object Privacy : Screen("privacy")
        }
    }

    data object ExtIntegrator : Screen("external")
}
