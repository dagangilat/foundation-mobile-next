package com.rarilabs.rarime.foundation.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.rarilabs.rarime.foundation.FoundationAuthManager
import com.rarilabs.rarime.util.ErrorHandler
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Drives [SignInScreen] and exposes the gate the whole app hangs off.
 *
 * Every suspend call here is wrapped: an uncaught rejection inside
 * viewModelScope kills the screen silently, leaving a spinner that never
 * resolves and no message telling the user why.
 */
@HiltViewModel
class SignInViewModel @Inject constructor(
    private val authManager: FoundationAuthManager,
) : ViewModel() {

    val isSignedIn: StateFlow<Boolean> = authManager.isSignedIn

    private val _codeSent = MutableStateFlow(false)
    val codeSent: StateFlow<Boolean> = _codeSent.asStateFlow()

    private val _isBusy = MutableStateFlow(false)
    val isBusy: StateFlow<Boolean> = _isBusy.asStateFlow()

    private val _errorMessage = MutableStateFlow("")
    val errorMessage: StateFlow<String> = _errorMessage.asStateFlow()

    fun sendCode(email: String) {
        if (_isBusy.value) return
        _isBusy.value = true
        _errorMessage.value = ""
        viewModelScope.launch {
            try {
                authManager.sendCode(email.trim())
                _codeSent.value = true
            } catch (e: Exception) {
                ErrorHandler.logError("SignInViewModel", "sendCode failed", e)
                _errorMessage.value = "Couldn't send the code. Try again."
            } finally {
                _isBusy.value = false
            }
        }
    }

    fun submitCode(code: String) {
        if (_isBusy.value) return
        _isBusy.value = true
        _errorMessage.value = ""
        viewModelScope.launch {
            try {
                // On success Firebase fires the auth-state listener,
                // isSignedIn flips and MainScreen swaps this screen away.
                authManager.submitCode(code.trim())
            } catch (e: Exception) {
                ErrorHandler.logError("SignInViewModel", "submitCode failed", e)
                _errorMessage.value = "That code didn't work. Try again."
            } finally {
                _isBusy.value = false
            }
        }
    }

    /** Returns to the email step, e.g. after a typo in the address. */
    fun editEmail() {
        _codeSent.value = false
        _errorMessage.value = ""
    }
}
