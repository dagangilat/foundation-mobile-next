package com.rarilabs.rarime.foundation.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.functions.FirebaseFunctionsException
import com.rarilabs.rarime.foundation.FoundationAuthManager
import com.rarilabs.rarime.util.ErrorHandler
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * `verifySignInCode` (foundation-next functions/index.js:3083-3096) throws
 * `failed-precondition` with a real, specific, written-for-humans message
 * per reason ("No sign-in code on file...", "Sign-in code expired...",
 * "Too many wrong attempts...", "Wrong code. N attempts left."). Before
 * 2026-09-04 (scoped re-review finding M-5) `submitCode` below caught every
 * error identically and showed a fixed generic string, discarding that
 * message - so an expired code or a lockout was mis-reported to the user
 * as an indistinguishable typo.
 *
 * `requestSignInCode` (used by `sendCode`) has no such path today - it only
 * throws `invalid-argument` for a malformed email, plus rate-limiting. Wiring
 * `sendCode` to the same classifier is a safe no-op now and means a future
 * per-reason `requestSignInCode` message surfaces automatically, without a
 * matching client change.
 * This surfaces the real message when the SDK gives us one; unrelated
 * errors (network, etc.) keep their existing generic fallback.
 *
 * Delegates to [signInErrorMessage] (codeName variant) rather than
 * comparing `e.code` to the `Code` enum directly: same reason as
 * `FoundationVerificationManager.firebaseRejectionMessage` -
 * `FirebaseFunctionsException.Code`'s static initializer touches unmocked
 * `android.util.SparseArray`, so merely referencing a `Code` constant
 * crashes a plain JVM unit test before the test body runs.
 */
internal fun signInErrorMessage(throwable: Throwable, fallback: String): String {
    val e = throwable as? FirebaseFunctionsException ?: return fallback
    return signInErrorMessage(codeName = e.code.name, message = e.message, fallback = fallback)
}

/** Pure decision, factored out for the same reason as the overload above. */
internal fun signInErrorMessage(codeName: String, message: String?, fallback: String): String {
    if (codeName != "FAILED_PRECONDITION") return fallback
    return message?.takeIf { it.isNotBlank() } ?: fallback
}

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
                _errorMessage.value = signInErrorMessage(e, fallback = "Couldn't send the code. Try again.")
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
                _errorMessage.value = signInErrorMessage(e, fallback = "That code didn't work. Try again.")
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
