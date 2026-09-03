package com.rarilabs.rarime.modules.home.v3

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import com.rarilabs.rarime.manager.NotificationManager
import com.rarilabs.rarime.manager.PassportManager
import com.rarilabs.rarime.manager.SettingsManager
import com.rarilabs.rarime.modules.manageWidgets.ManageWidgetsManager
import com.rarilabs.rarime.store.SecureSharedPrefsManager
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    app: Application,
    passportManager: PassportManager,
    private val widgetsManager: ManageWidgetsManager,
    notificationManager: NotificationManager,
    settingsManager: SettingsManager,
    private val sharedPrefsManager: SecureSharedPrefsManager
) : AndroidViewModel(app) {

    val colorScheme = settingsManager.colorScheme
    var visibleWidgets = widgetsManager.visibleWidgets

    val passport = passportManager.passport

    val notifications = notificationManager.notificationList

    fun saveIsShownWelcome(boolean: Boolean) {
        sharedPrefsManager.saveIsShownWelcome(boolean)
    }

    fun getIsShownWelcome(): Boolean {
        return sharedPrefsManager.getIsShownWelcome()
    }
}