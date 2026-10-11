package org.peerlink.core.event;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.Consumer;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Internal event bus for the Local Node engine.
 *
 * <p>Events flow in one direction: engine → subscribers. Subscribers cannot
 * produce events back into the bus (they must use the engine API for that).
 *
 * <p>Thread model: {@link #publish(NodeEvent)} may be called from any thread.
 * Subscribers are notified on a dedicated single-threaded executor to decouple
 * event production from consumption and prevent subscriber latency from blocking
 * the engine.
 *
 * <p>Subscribers must not throw unchecked exceptions; exceptions are caught,
 * logged, and suppressed to prevent one bad subscriber from blocking others.
 */
public final class NodeEventBus {
    private static final Logger log = LoggerFactory.getLogger(NodeEventBus.class);

    private final List<Consumer<NodeEvent>> subscribers = new CopyOnWriteArrayList<>();
    private final AtomicLong sequenceCounter = new AtomicLong(0);
    private final Executor notifyExecutor;

    public NodeEventBus() {
        this(Executors.newSingleThreadExecutor(r -> {
            Thread t = new Thread(r, "peerlink-event-bus");
            t.setDaemon(true);
            return t;
        }));
    }

    public NodeEventBus(Executor notifyExecutor) {
        this.notifyExecutor = notifyExecutor;
    }

    /** Register a subscriber. Safe to call from any thread; registration is immediate. */
    public void subscribe(Consumer<NodeEvent> subscriber) {
        subscribers.add(subscriber);
    }

    /** Deregister a subscriber. */
    public void unsubscribe(Consumer<NodeEvent> subscriber) {
        subscribers.remove(subscriber);
    }

    /**
     * Publish an event to all subscribers. Returns the sequence number assigned.
     * Non-blocking: delivery is asynchronous via the dedicated executor.
     */
    public long publish(NodeEvent event) {
        // sequence is already embedded in the event by construction; we just log it
        long seq = event.sequenceNumber();
        notifyExecutor.execute(() -> {
            for (Consumer<NodeEvent> subscriber : subscribers) {
                try {
                    subscriber.accept(event);
                } catch (Exception e) {
                    log.error("NodeEventBus subscriber threw exception for event seq={}: {}",
                            seq, e.getMessage(), e);
                }
            }
        });
        return seq;
    }

    /**
     * Allocate the next event sequence number. Engine components call this to
     * produce monotonically increasing sequence numbers before constructing events.
     */
    public long nextSequence() {
        return sequenceCounter.getAndIncrement();
    }

    /** Number of active subscribers (useful for testing). */
    public int subscriberCount() {
        return subscribers.size();
    }
}
