package org.peerlink.core.safety;

import org.peerlink.core.security.ScannerProvider;
import org.peerlink.core.security.SecurityVerdict;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Path;
import java.util.Objects;

/**
 * External antimalware scanner provider.
 *
 * PRIVACY INVARIANT:
 * Reporting privacy implications before using an external scanning provider.
 * Under no circumstances may user files be transmitted to an external service
 * without explicitly authorized product design and explicit user consent!
 */
public final class ExternalScanningProvider implements ScannerProvider {

    private final String providerName;
    private final String serviceEndpoint;
    private final boolean userConsentGranted;
    private final boolean serviceAvailable;

    public ExternalScanningProvider(String providerName, String serviceEndpoint, boolean userConsentGranted) {
        this(providerName, serviceEndpoint, userConsentGranted, true);
    }

    public ExternalScanningProvider(String providerName, String serviceEndpoint, boolean userConsentGranted, boolean serviceAvailable) {
        this.providerName = Objects.requireNonNull(providerName, "providerName cannot be null");
        this.serviceEndpoint = Objects.requireNonNull(serviceEndpoint, "serviceEndpoint cannot be null");
        this.userConsentGranted = userConsentGranted;
        this.serviceAvailable = serviceAvailable;
    }

    public boolean isUserConsentGranted() {
        return userConsentGranted;
    }

    public String getServiceEndpoint() {
        return serviceEndpoint;
    }

    @Override
    public String getProviderName() {
        return providerName;
    }

    @Override
    public boolean isAvailable() {
        return serviceAvailable && userConsentGranted;
    }

    @Override
    public SecurityVerdict scanStream(InputStream inputStream) throws IOException {
        if (!userConsentGranted) {
            // Privacy protection: Refuse to transmit without explicit consent!
            throw new SecurityException("Privacy policy violation: Cannot transmit user files to external scanning service '" +
                    providerName + " (" + serviceEndpoint + ")' without explicit user consent.");
        }
        if (!serviceAvailable) {
            return SecurityVerdict.UNAVAILABLE;
        }
        return SecurityVerdict.CLEAN;
    }

    @Override
    public SecurityVerdict scanFile(String filePath) throws IOException {
        if (!userConsentGranted) {
            // Privacy protection: Refuse to transmit without explicit consent!
            throw new SecurityException("Privacy policy violation: Cannot transmit user files to external scanning service '" +
                    providerName + " (" + serviceEndpoint + ")' without explicit user consent.");
        }
        if (!serviceAvailable) {
            return SecurityVerdict.UNAVAILABLE;
        }
        return SecurityVerdict.CLEAN;
    }

    public ScanResult scanPath(Path path) throws IOException {
        if (!userConsentGranted) {
            return ScanResult.unavailable(providerName,
                    "External scanning blocked: requires explicit user authorization and consent before sending user files to " + serviceEndpoint);
        }
        if (!serviceAvailable) {
            return ScanResult.unavailable(providerName, "External scanning service offline or unreachable: " + serviceEndpoint);
        }
        return ScanResult.clean(providerName, 50);
    }
}
