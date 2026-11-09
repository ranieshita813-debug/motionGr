package com.motiongr.videoedit.export

import java.util.concurrent.atomic.AtomicBoolean

/**
 * Cancellation token for long-running operations.
 * Allows cooperative cancellation without throwing exceptions.
 */
class CancellationToken {
    private val cancelled = AtomicBoolean(false)
    private val listeners = mutableListOf<() -> Unit>()

    /** Returns true if cancellation has been requested */
    val isCancelled: Boolean get() = cancelled.get()

    /** Request cancellation */
    fun cancel() {
        if (cancelled.compareAndSet(false, true)) {
            // Notify all listeners
            for (listener in listeners) {
                try {
                    listener()
                } catch (_: Exception) {
                    // Ignore listener exceptions
                }
            }
            listeners.clear()
        }
    }

    /** Register a callback to be invoked when cancelled */
    fun onCancelled(listener: () -> Unit) {
        if (isCancelled) {
            try {
                listener()
            } catch (_: Exception) {}
        } else {
            listeners.add(listener)
        }
    }

    /** Throw exception if cancelled (for use in blocking operations) */
    fun throwIfCancelled(): CancellationException {
        if (isCancelled) throw CancellationException("Operation cancelled")
        return CancellationException("Not cancelled") // Never thrown
    }

    /** Reset the token (for reuse in tests) */
    internal fun reset() {
        cancelled.set(false)
        listeners.clear()
    }
}

/** Exception thrown when operation is cancelled */
class CancellationException(message: String) : Exception(message)

/** Extension to check cancellation in loops */
inline fun CancellationToken.ensureActive(): Boolean {
    return !isCancelled
}