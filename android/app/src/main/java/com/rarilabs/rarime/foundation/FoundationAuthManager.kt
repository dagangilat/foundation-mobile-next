package com.rarilabs.rarime.foundation

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Foundation's Firebase identity, layered on top of Rarimo's local identity
 * secret. Rarimo's app has no server-side account at all; every Foundation
 * callable runs requireAuth, so a Firebase uid is a hard prerequisite.
 */
@Singleton
class FoundationAuthManager internal constructor(
    private val functionsService: FoundationFunctionsService,
    /**
     * Indirection so this class can be constructed off-device.
     * `FirebaseAuth.getInstance()` throws when no FirebaseApp is initialized,
     * which is every plain JVM unit test - resolving it through a provider
     * (rather than catching the throw) keeps a genuine misconfiguration on
     * device loud instead of silently degrading to a signed-out app.
     */
    private val authProvider: () -> FirebaseAuth?,
) {
    @Inject
    constructor(functionsService: FoundationFunctionsService) : this(
        functionsService,
        { FirebaseAuth.getInstance() },
    )

    private val auth: FirebaseAuth? by lazy { authProvider() }

    private val _uid = MutableStateFlow(auth?.currentUser?.uid)
    val uid: StateFlow<String?> = _uid.asStateFlow()

    private val _isSignedIn = MutableStateFlow(auth?.currentUser != null)
    val isSignedIn: StateFlow<Boolean> = _isSignedIn.asStateFlow()

    private var pendingEmail: String? = null

    init {
        auth?.addAuthStateListener { a ->
            _uid.value = a.currentUser?.uid
            _isSignedIn.value = a.currentUser != null
        }
    }

    suspend fun sendCode(email: String) {
        functionsService.requestSignInCode(email)
        pendingEmail = email
    }

    suspend fun submitCode(code: String) {
        val email = pendingEmail ?: error("no pending email; call sendCode first")
        val firebaseAuth = auth ?: error("FirebaseAuth is unavailable; Firebase is not initialized")
        val result = functionsService.verifySignInCode(email, code)
        firebaseAuth.signInWithCustomToken(result.customToken).await()
        pendingEmail = null
    }

    fun signOut() {
        auth?.signOut()
        _uid.value = null
        _isSignedIn.value = false
        pendingEmail = null
    }

    companion object {
        /** Constructs an instance without Hilt or Firebase, for unit tests. */
        fun forTesting(): FoundationAuthManager =
            FoundationAuthManager(FoundationFunctionsService()) { null }
    }
}
