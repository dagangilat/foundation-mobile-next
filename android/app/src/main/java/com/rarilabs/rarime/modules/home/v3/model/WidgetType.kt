package com.rarilabs.rarime.modules.home.v3.model

/**
 * Home carousel cards. The earn, voting, hidden-prize and likeness cards
 * belonged to the upstream product modules removed in Task C5, leaving the
 * recovery-method card as the only widget. `layoutId` values are kept as-is so
 * the persisted sort order does not shift; `readVisibleWidgets` decodes with
 * `runCatching { valueOf(name) }`, so upgrading devices holding the removed
 * names degrade cleanly and need no migration.
 */
enum class WidgetType(val layoutId: Int) {
    RECOVERY_METHOD(3),
}
