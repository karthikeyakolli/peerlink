package org.peerlink.core.transfer.congestion;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Adaptive Congestion Controller Tests")
class AdaptiveCongestionControllerTest {

    @Test
    @DisplayName("Probes bandwidth upwards when network latency is low and queueing delay is clean")
    void probesUpwardsOnCleanNetwork() {
        long initialRate = 1_000_000L; // 1 MB/s
        long minRate = 100_000L;      // 100 KB/s
        long maxRate = 10_000_000L;   // 10 MB/s

        AdaptiveCongestionController controller = new AdaptiveCongestionController(
                initialRate, minRate, maxRate, 50);

        // Baseline RTT sample: 10ms
        controller.recordSample(10, 64 * 1024);

        // Successive clean samples (12ms, 11ms, 10ms)
        for (int i = 0; i < 5; i++) {
            controller.recordSample(11, 64 * 1024);
        }

        assertTrue(controller.getCurrentRateBytesPerSec() > initialRate,
                "Controller should increase rate when queue delay is low");
    }

    @Test
    @DisplayName("Throttles back when queueing delay exceeds target threshold (Congestion Backoff)")
    void throttlesBackOnBufferbloatDelay() {
        long initialRate = 5_000_000L; // 5 MB/s
        long minRate = 200_000L;
        long maxRate = 20_000_000L;

        AdaptiveCongestionController controller = new AdaptiveCongestionController(
                initialRate, minRate, maxRate, 40); // 40ms target delay

        // Baseline RTT: 15ms
        controller.recordSample(15, 64 * 1024);

        // Sudden latency spike to 120ms (queue delay = 105ms > target 40ms)
        controller.recordSample(120, 64 * 1024);

        assertTrue(controller.getCurrentRateBytesPerSec() < initialRate,
                "Controller should back off when queue delay exceeds target");

        // Second spike
        long rateAfterFirstSpike = controller.getCurrentRateBytesPerSec();
        controller.recordSample(140, 64 * 1024);
        assertTrue(controller.getCurrentRateBytesPerSec() < rateAfterFirstSpike,
                "Successive spikes should trigger multiplicative backoff");
    }

    @Test
    @DisplayName("Rate never drops below minRateBytesPerSec even under heavy congestion")
    void respectsMinRateFloor() {
        long minRate = 50_000L;
        AdaptiveCongestionController controller = new AdaptiveCongestionController(
                100_000L, minRate, 10_000_000L, 20);

        controller.recordSample(10, 32 * 1024);

        // Simulate 20 terrible latency spikes
        for (int i = 0; i < 20; i++) {
            controller.recordSample(500, 32 * 1024);
        }

        assertEquals(minRate, controller.getCurrentRateBytesPerSec(),
                "Rate must not drop below configured minRate floor");
    }

    @Test
    @DisplayName("Packet loss or timeout halves current rate immediately")
    void emergencyDropOnTimeout() {
        long initialRate = 4_000_000L;
        AdaptiveCongestionController controller = new AdaptiveCongestionController(
                initialRate, 100_000L, 10_000_000L, 30);

        controller.onTimeoutOrLoss();

        assertEquals(initialRate / 2, controller.getCurrentRateBytesPerSec(),
                "Timeout or loss must halve transmission rate");
    }
}
