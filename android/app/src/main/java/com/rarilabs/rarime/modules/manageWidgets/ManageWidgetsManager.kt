package com.rarilabs.rarime.modules.manageWidgets

import com.rarilabs.rarime.modules.home.v3.model.WidgetType
import com.rarilabs.rarime.store.SecureSharedPrefsManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Tracks which home-carousel cards are visible.
 *
 * Upstream also auto-added an EARN card once the user's points balance went
 * above zero, which is why this used to observe `WalletManager.pointsToken`.
 * Both the Earn module and the wallet are removed, so the manager no longer
 * depends on any balance source and `RECOVERY_METHOD` is the only card left.
 */
@Singleton
class ManageWidgetsManager @Inject constructor(
    private val sharedPrefsManager: SecureSharedPrefsManager
) {
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val _visibleWidgets = MutableStateFlow<List<WidgetType>>(emptyList())
    val visibleWidgets: StateFlow<List<WidgetType>> get() = _visibleWidgets.asStateFlow()

    private val allManaged = listOf(
        WidgetType.RECOVERY_METHOD
    )
    val managedWidgets: StateFlow<List<WidgetType>> = MutableStateFlow(allManaged).asStateFlow()

    init {
        scope.launch {
            loadInitialWidgets()
        }
    }

    private fun loadInitialWidgets() {
        val stored = sharedPrefsManager.readVisibleWidgets()
            .orEmpty()
            .toMutableList()

        if (stored.isEmpty()) {
            stored += WidgetType.RECOVERY_METHOD
        }

        updateAndPersist(stored)
    }

    fun setVisibleWidgets(newVisible: List<WidgetType>) {
        updateAndPersist(newVisible)
    }

    @Synchronized
    fun add(widget: WidgetType) {
        val updated = (_visibleWidgets.value + widget)
            .distinct()
        updateAndPersist(updated)
    }

    @Synchronized
    fun remove(widget: WidgetType) {
        val updated = _visibleWidgets.value - widget
        updateAndPersist(updated)
    }

    private fun updateAndPersist(list: List<WidgetType>) {
        val processedSortedList = list
            .distinct()
            .sortedBy { it.layoutId }

        if (_visibleWidgets.value != processedSortedList) {
            _visibleWidgets.value = processedSortedList
        }
        sharedPrefsManager.saveVisibleWidgets(processedSortedList)
    }
}
