package com.rarilabs.rarime.modules.main


import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.zIndex
import androidx.core.content.ContextCompat
import androidx.core.net.toUri
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.currentBackStackEntryAsState
import com.rarilabs.rarime.R
import com.rarilabs.rarime.foundation.ui.BrandLockup
import com.rarilabs.rarime.foundation.ui.FoundationIndeterminateBar
import com.rarilabs.rarime.foundation.ui.PillarsHero
import com.rarilabs.rarime.foundation.ui.SignInScreen
import com.rarilabs.rarime.foundation.ui.SignInViewModel
import com.rarilabs.rarime.modules.qr.ScanQrScreen
import com.rarilabs.rarime.ui.components.AppBottomSheet
import com.rarilabs.rarime.ui.components.AppIcon
import com.rarilabs.rarime.ui.components.UiSnackbarDefault
import com.rarilabs.rarime.ui.components.rememberAppSheetState
import com.rarilabs.rarime.ui.theme.AppTheme
import com.rarilabs.rarime.ui.theme.FoundationBrand
import com.rarilabs.rarime.ui.theme.FoundationTheme
import com.rarilabs.rarime.ui.theme.FoundationType
import com.rarilabs.rarime.util.Screen

val mainRoutes = listOf(
    Screen.Main.Home.route,
    Screen.Main.Profile.route,
    Screen.Main.Identity.route
)

val LocalMainViewModel = compositionLocalOf<MainViewModel> { error("No MainViewModel provided") }

@Composable
fun MainScreen(
    mainViewModel: MainViewModel = hiltViewModel(),
    navController: NavHostController
) {

    LaunchedEffect(Unit) {
        mainViewModel.initApp()
    }


    CompositionLocalProvider(LocalMainViewModel provides mainViewModel) {
        MainScreenContent(navController = navController)
    }
}

/**
 * Launch/loading: the lockup top-left, the pillars in the mesh hero, and a
 * quiet "Loading Foundation…" line over a sweeping green bar at the bottom.
 * The pre-fork iOS `LoadingView`, so launch -> loading -> Home reads as one
 * continuous opening.
 */
@Composable
fun AppLoadingScreen() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(color = FoundationBrand.Bg)
            .systemBarsPadding()
            .padding(start = 24.dp, end = 24.dp, top = 20.dp, bottom = 40.dp),
    ) {
        Row(modifier = Modifier.height(44.dp), verticalAlignment = Alignment.CenterVertically) {
            BrandLockup()
        }
        Spacer(modifier = Modifier.height(24.dp))
        PillarsHero()
        Spacer(modifier = Modifier.weight(1f))
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = "Loading Foundation…",
                style = FoundationType.callout,
                color = FoundationBrand.Muted,
            )
            FoundationIndeterminateBar()
        }
    }
}

@Composable
fun AppLoadingFailedScreen() {
    Box(
        modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center
    ) {
        AppIcon(id = R.drawable.ic_warning, tint = FoundationTheme.colors.errorDark, size = 140.dp)
    }
}

@SuppressLint("UnusedMaterial3ScaffoldPaddingParameter")
@Composable
fun MainScreenContent(
    navController: NavHostController,
) {
    val mainViewModel = LocalMainViewModel.current
    val context = LocalContext.current


    val isModalShown by mainViewModel.isModalShown.collectAsState()
    val modalContent by mainViewModel.modalContent.collectAsState()

    val snackbarHostState by mainViewModel.snackbarHostState.collectAsState()
    val snackbarContent by mainViewModel.snackbarContent.collectAsState()

    val colorSchema by mainViewModel.colorScheme.collectAsState()

    // Foundation's sign-in gate. It sits above the NavHost, so it precedes the
    // existing intro/passcode flow rather than replacing it: on first sign-in
    // the NavHost composes for the first time, at Screen.Loading, and that flow
    // runs untouched. Note this is NOT a general reset - navController is owned
    // above this composable, so a future sign-out/sign-in within one process
    // would resume the prior back stack, not restart at Loading.
    // Every Foundation callable runs requireAuth, so there is nothing useful
    // the app can do before this.
    val signInViewModel: SignInViewModel = hiltViewModel()
    val isSignedIn by signInViewModel.isSignedIn.collectAsState()

    // Android 13+ shows no notifications until the user allows them. Ask once
    // signed in, like iOS does on its first Home appearance.
    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { }
    LaunchedEffect(isSignedIn) {
        if (isSignedIn &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    val qrCodeState = rememberAppSheetState()
    val isBottomBarShown by mainViewModel.isBottomBarShown.collectAsState()
    // Use remember to cache navBackStackEntry and currentRoute
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute by remember(navBackStackEntry) {
        derivedStateOf { navBackStackEntry?.destination?.route }
    }

    // Compute shouldShowBottomBar based on currentRoute
    val shouldShowBottomBar by remember(currentRoute) {
        derivedStateOf { currentRoute != null && currentRoute in mainRoutes }
    }

    // Use LaunchedEffect to update bottom bar visibility when shouldShowBottomBar changes
    LaunchedEffect(shouldShowBottomBar) {
        mainViewModel.setBottomBarVisibility(shouldShowBottomBar)
    }

    val qrCodeSheetState = rememberUpdatedState(qrCodeState)

    // Define navigation functions using remember to prevent recomposition
    val simpleNavigate = remember(navController) {
        { route: String ->
            navController.navigate(route)
        }
    }

    val navigateWithPopUp = remember(navController) {
        { route: String ->
            Log.d("URL string", route)
            if (route == Screen.Main.QrScan.route) {
                val currentQrCodeSheetState = qrCodeSheetState.value
                currentQrCodeSheetState.show()
            } else {
                navController.navigate(route) {
                    popUpTo(navController.graph.id) { inclusive = true }
                    restoreState = true
                    launchSingleTop = true
                }
            }
        }
    }

    AppTheme(colorScheme = colorSchema) {
        if (!isSignedIn) {
            SignInScreen(viewModel = signInViewModel)
            return@AppTheme
        }

        Scaffold(
            containerColor = FoundationTheme.colors.backgroundPrimary,
            // No bottom tab bar in the Foundation shell: Home carries the
            // header (profile) and the passport/QR entry points itself, and the
            // Identity and QR tabs are reached from there. BottomTabBar and the
            // isBottomBarShown plumbing are left in place, just not drawn.
            bottomBar = {},

            snackbarHost = {
                // Show custom snackbar instead of `SnackbarHost`
                snackbarContent?.let { snackContent ->
                    Column(
                        modifier = Modifier
                            .zIndex(100f)
                            .fillMaxWidth()
                            .padding(horizontal = 20.dp)
                    ) {
                        UiSnackbarDefault(snackContent)

                        // Disappear automatically
                        LaunchedEffect(snackContent) {
                            kotlinx.coroutines.delay(
                                when (snackContent.duration) {
                                    SnackbarDuration.Short -> 2000
                                    SnackbarDuration.Long -> 4000
                                    SnackbarDuration.Indefinite -> Long.MAX_VALUE
                                }
                            )
                            mainViewModel.clearSnackbarOptions()
                        }
                    }
                }
            },
        ) { innerPaddings ->
            mainViewModel.setScreenInsets(
                top = innerPaddings.calculateTopPadding().value,
                bottom = innerPaddings.calculateBottomPadding().value
            )

            ScreenBarsColor(
                colorScheme = colorSchema, route = currentRoute ?: ""
            )


            MainScreenRoutes(
                navController = navController,
                simpleNavigate = { simpleNavigate(it) },
                navigateWithPopUp = { navigateWithPopUp(it) },
            )

            if (isModalShown) {
                Dialog(onDismissRequest = { mainViewModel.setModalVisibility(false) }) {
                    modalContent()
                }
            }

            AppBottomSheet(
                state = qrCodeState, fullScreen = true, isHeaderEnabled = false
            ) {
                ScanQrScreen(onBack = {
                    qrCodeState.hide()
                }, onScan = {
                    val uri = it.toUri()
                    qrCodeState.hide()
                    mainViewModel.setExtIntDataURI(uri)
                })
            }
        }
    }


}


@Preview
@Composable
private fun AppLoadingScreenPreview() {
    AppLoadingScreen()
}