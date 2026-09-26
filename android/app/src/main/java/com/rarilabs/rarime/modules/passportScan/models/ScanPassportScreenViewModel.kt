package com.rarilabs.rarime.modules.passportScan.models

import androidx.lifecycle.ViewModel
import com.rarilabs.rarime.api.registration.models.LightRegistrationData
import com.rarilabs.rarime.data.enums.PassportStatus
import com.rarilabs.rarime.foundation.AppNotification
import com.rarilabs.rarime.foundation.AppNotificationStore
import com.rarilabs.rarime.manager.IdentityManager
import com.rarilabs.rarime.manager.NfcAvailability
import com.rarilabs.rarime.manager.NfcManager
import com.rarilabs.rarime.manager.PassportManager
import com.rarilabs.rarime.manager.RegistrationManager
import com.rarilabs.rarime.util.ErrorHandler
import com.rarilabs.rarime.util.data.UniversalProof
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject

@HiltViewModel
class ScanPassportScreenViewModel @Inject constructor(
    private val passportManager: PassportManager,
    private val identityManager: IdentityManager,
    private val registrationManager: RegistrationManager,
    private val nfcManager: NfcManager,
    private val notificationStore: AppNotificationStore,
) : ViewModel() {
    val eDocument = registrationManager.eDocument

    /** Whether this phone can read the chip; the chip explainer says so before the scan. */
    val nfcAvailability: StateFlow<NfcAvailability> = nfcManager.availabilityState

    fun refreshNfcAvailability(): NfcAvailability = nfcManager.refreshAvailability()

    /**
     * The reason of the last chip read that failed with no successful read
     * since. A failed read keeps the person on the chip step to try again,
     * so it goes behind Home's bell only if they leave the flow without
     * a read ([reportUnrecoveredChipFailure]), once, not per retry.
     */
    private var unrecoveredChipFailure: String? = null

    fun onChipReadFailed(reason: String) {
        unrecoveredChipFailure = reason
    }

    fun onChipReadSucceeded() {
        unrecoveredChipFailure = null
    }

    /** Leaving the flow: an unrecovered chip failure goes behind the bell. */
    fun reportUnrecoveredChipFailure() {
        val reason = unrecoveredChipFailure ?: return
        unrecoveredChipFailure = null
        notificationStore.postVerificationFailure(
            reason = reason,
            retry = AppNotification.Retry.SCAN_PASSPORT,
        )
    }

    /** Left some other way (system back pops the route): still report it. */
    override fun onCleared() {
        reportUnrecoveredChipFailure()
        super.onCleared()
    }

    fun rejectRevocation() {
        ErrorHandler.logDebug("ScanPassportScreenViewModel", "rejectRevocation")
        resetPassportState()
    }

    fun resetPassportState() {
        ErrorHandler.logDebug("ScanPassportScreenViewModel", "resetPassportState")
        passportManager.deletePassport()
    }

    fun finishRevocation() {
        ErrorHandler.logDebug("ScanPassportScreenViewModel", "finishRevocation")
        savePassport()
        saveRegistrationProof(registrationManager.registrationProof.value!!)
    }

    fun setPassportTEMP(eDocument: EDocument?) {
        registrationManager.setEDocument(eDocument)
    }

    fun savePassport() {
        registrationManager.eDocument.value?.let {
            passportManager.setPassport(eDocument.value)
            passportManager.updatePassportStatus(status = PassportStatus.UNREGISTERED)
        }
    }

    fun saveRegistrationProof(registrationProof: UniversalProof) {
        ErrorHandler.logDebug("ScanPassportScreenViewModel", "saveRegistrationProof")
        identityManager.setRegistrationProof(registrationProof)
    }

    fun saveLightRegistrationData(lightRegistrationData: LightRegistrationData?) {
        identityManager.setLightRegistrationData(lightRegistrationData)
    }
}
