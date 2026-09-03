package com.rarilabs.rarime

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.appcompat.app.AppCompatActivity
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.WindowCompat
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import com.rarilabs.rarime.manager.NfcManager
import com.rarilabs.rarime.manager.ScanNFCState
import com.rarilabs.rarime.modules.appUpdate.InAppUpdate
import com.rarilabs.rarime.modules.main.MainScreen
import com.rarilabs.rarime.modules.main.MainViewModel
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : AppCompatActivity() {
    @Inject
    lateinit var nfcManager: NfcManager

    private val mainViewModel: MainViewModel by viewModels()

    private var navController: NavHostController? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        intent.addFlags(
            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_CLEAR_TASK or Intent.FLAG_ACTIVITY_NEW_TASK
        )



        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.auto(
                android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT
            ), navigationBarStyle = SystemBarStyle.auto(
                android.graphics.Color.TRANSPARENT,
                android.graphics.Color.TRANSPARENT,
            )
        )

        handleDeepLink(intent.data, isColdStart = true)

        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = android.graphics.Color.TRANSPARENT

        installSplashScreen()
        nfcManager.activity = this

        setContent {
            navController = rememberNavController()
            InAppUpdate(activity = this)
            MainScreen(
                mainViewModel = mainViewModel,
                navController = navController!!,
            )
        }
    }

    override fun onPause() {
        super.onPause()
        if (nfcManager.state.value != ScanNFCState.NOT_SCANNING) {
            nfcManager.disableForegroundDispatch()
        }
    }


    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        handleDeepLink(intent.data, false)

        nfcManager.handleNewIntent(intent)
    }

    override fun onDestroy() {
        Log.d("MainActivityBW", "onDestroy called")
        super.onDestroy()
    }

    private fun handleDeepLink(uri: Uri?, isColdStart: Boolean) {
        uri ?: return
        Log.i("MainActivity", "handleDeepLink(uri=$uri, cold=$isColdStart)")
        mainViewModel.setExtIntDataURI(uri)
    }
}