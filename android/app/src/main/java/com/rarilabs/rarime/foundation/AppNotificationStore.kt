package com.rarilabs.rarime.foundation

import android.content.Context
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import com.google.gson.reflect.TypeToken
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * One entry behind Home's bell.
 *
 * [message] is reason text only: never a name, passport number or key. The
 * title comes from [type] (strings.xml), so it follows the app's language.
 * For the success types an empty [message] means "use the type's own line".
 */
data class AppNotification(
    val id: String,
    val type: Type,
    val message: String,
    val timeMillis: Long,
    val isRead: Boolean,
    val retry: Retry?,
) {
    enum class Type(val isError: Boolean) {
        /** Any other error that used to pop up as a snackbar or toast. */
        ERROR(true),

        /** "Verification didn't finish": offers Try again and Share app log. */
        VERIFICATION_FAILED(true),

        /** "Passport checked": the passport part finished. */
        PASSPORT_CHECKED(false),

        /** "You're verified": Foundation confirmed the member. */
        VERIFIED(false),
    }

    /** What "Try again" on a failed verification entry does. */
    enum class Retry {
        /** The passport part failed: open the passport flow again. */
        SCAN_PASSPORT,

        /** Foundation's own check failed: ask Foundation again. */
        FINISH_VERIFICATION,
    }

    val isError: Boolean get() = type.isError
    val isVerificationFailure: Boolean get() = type == Type.VERIFICATION_FAILED
}

/** Where the list is kept between launches. */
interface AppNotificationStorage {
    fun read(): String?
    fun write(json: String?)
}

private class SharedPrefsNotificationStorage(context: Context) : AppNotificationStorage {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override fun read(): String? = prefs.getString(KEY_ENTRIES, null)

    // commit, not apply: account deletion restarts the process right after
    // clearing, and an apply() could still be in flight.
    override fun write(json: String?) {
        prefs.edit().apply {
            if (json == null) remove(KEY_ENTRIES) else putString(KEY_ENTRIES, json)
        }.commit()
    }

    companion object {
        private const val PREFS_NAME = "foundation_app_notifications"
        private const val KEY_ENTRIES = "entries"
    }
}

/**
 * The app's own notifications, shown behind Home's bell, newest first.
 *
 * Errors that used to pop up over the screen (error snackbars and toasts)
 * land here instead; see `MainViewModel.showSnackbar`. Kept in
 * SharedPreferences so the list survives a relaunch, capped at [MAX_ENTRIES],
 * and cleared on sign out and account deletion.
 *
 * Mirrors iOS's `AppNotificationStore`.
 */
@Singleton
class AppNotificationStore internal constructor(
    private val storage: AppNotificationStorage,
    private val clock: () -> Long = System::currentTimeMillis,
    private val newId: () -> String = { UUID.randomUUID().toString() },
) {
    @Inject
    constructor(@ApplicationContext context: Context) : this(SharedPrefsNotificationStorage(context))

    private val gson = Gson()
    private val lock = Any()

    private val _entries = MutableStateFlow(load())
    val entries: StateFlow<List<AppNotification>> = _entries.asStateFlow()

    fun postError(message: String) = post(AppNotification.Type.ERROR, message, retry = null)

    /** "Verification didn't finish" with the reason, Try again and Share app log. */
    fun postVerificationFailure(reason: String, retry: AppNotification.Retry) =
        post(AppNotification.Type.VERIFICATION_FAILED, reason, retry)

    fun postPassportChecked() = post(AppNotification.Type.PASSPORT_CHECKED, "", retry = null)

    fun postVerified() = post(AppNotification.Type.VERIFIED, "", retry = null)

    private fun post(type: AppNotification.Type, message: String, retry: AppNotification.Retry?) {
        val text = message.trim().let {
            if (it.length > MAX_MESSAGE_LENGTH) it.take(MAX_MESSAGE_LENGTH) + "…" else it
        }
        update { current ->
            // The same unread entry again (a retried call failing the same
            // way): move it to the top instead of stacking duplicates.
            val duplicate = current.firstOrNull {
                !it.isRead && it.type == type && it.message == text && it.retry == retry
            }
            val entry = duplicate?.copy(timeMillis = clock()) ?: AppNotification(
                id = newId(),
                type = type,
                message = text,
                timeMillis = clock(),
                isRead = false,
                retry = retry,
            )
            (listOf(entry) + current.filter { it.id != entry.id }).take(MAX_ENTRIES)
        }
    }

    /** Opening the bell's sheet reads everything. */
    fun markAllRead() {
        update { current ->
            if (current.none { !it.isRead }) current else current.map { it.copy(isRead = true) }
        }
    }

    /** Sign out and account deletion: the list describes the departing member. */
    fun clear() {
        synchronized(lock) {
            _entries.value = emptyList()
            storage.write(null)
        }
    }

    private fun update(transform: (List<AppNotification>) -> List<AppNotification>) {
        synchronized(lock) {
            val current = _entries.value
            val next = transform(current)
            if (next === current) return
            _entries.value = next
            storage.write(gson.toJson(next.map(StoredEntry::from)))
        }
    }

    private fun load(): List<AppNotification> {
        val json = storage.read() ?: return emptyList()
        return try {
            val type = object : TypeToken<List<StoredEntry>>() {}.type
            gson.fromJson<List<StoredEntry>>(json, type)
                .orEmpty()
                .mapNotNull { it.toEntry() }
                .take(MAX_ENTRIES)
        } catch (e: Exception) {
            emptyList()
        }
    }

    /**
     * Stored shape. Enums as names and every field nullable, so an entry
     * written by another app version is skipped rather than crashing a
     * launch (Gson fills missing fields with null, even for Kotlin non-null
     * types).
     */
    private data class StoredEntry(
        @SerializedName("id") val id: String?,
        @SerializedName("type") val type: String?,
        @SerializedName("message") val message: String?,
        @SerializedName("timeMillis") val timeMillis: Long?,
        @SerializedName("isRead") val isRead: Boolean?,
        @SerializedName("retry") val retry: String?,
    ) {
        fun toEntry(): AppNotification? {
            val entryType = AppNotification.Type.entries.firstOrNull { it.name == type } ?: return null
            return AppNotification(
                id = id ?: return null,
                type = entryType,
                message = message.orEmpty(),
                timeMillis = timeMillis ?: 0L,
                isRead = isRead ?: true,
                retry = AppNotification.Retry.entries.firstOrNull { it.name == retry },
            )
        }

        companion object {
            fun from(entry: AppNotification) = StoredEntry(
                id = entry.id,
                type = entry.type.name,
                message = entry.message,
                timeMillis = entry.timeMillis,
                isRead = entry.isRead,
                retry = entry.retry?.name,
            )
        }
    }

    companion object {
        const val MAX_ENTRIES = 50
        private const val MAX_MESSAGE_LENGTH = 600
    }
}

/** Drives the red dot on the bell: an error the person hasn't seen yet. */
val List<AppNotification>.hasUnreadErrors: Boolean
    get() = any { !it.isRead && it.isError }

/** Lets Home's card say "The bell has the details." after a failed try. */
val List<AppNotification>.hasUnreadVerificationFailure: Boolean
    get() = any { !it.isRead && it.isVerificationFailure }
