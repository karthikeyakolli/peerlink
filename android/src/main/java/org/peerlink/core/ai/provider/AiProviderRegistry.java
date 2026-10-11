package org.peerlink.core.ai.provider;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Registry and router for AI model providers.
 */
public final class AiProviderRegistry {
    private final Map<AiProviderType, AiProvider> providers = new ConcurrentHashMap<>();
    private volatile AiProviderType activeProviderType;

    public AiProviderRegistry() {
        this(new SimulatedAiProvider());
    }

    public AiProviderRegistry(AiProvider defaultProvider) {
        registerProvider(defaultProvider);
        this.activeProviderType = defaultProvider.getProviderType();
    }

    public void registerProvider(AiProvider provider) {
        Objects.requireNonNull(provider, "provider is required");
        providers.put(provider.getProviderType(), provider);
    }

    public void setActiveProviderType(AiProviderType type) {
        if (!providers.containsKey(type)) {
            throw new IllegalArgumentException("Provider type not registered: " + type);
        }
        this.activeProviderType = type;
    }

    public Optional<AiProvider> getActiveProvider() {
        AiProvider active = providers.get(activeProviderType);
        if (active != null && active.isAvailable()) {
            return Optional.of(active);
        }
        // Fallback to any available provider (preferring SIMULATED if present)
        if (providers.containsKey(AiProviderType.SIMULATED) && providers.get(AiProviderType.SIMULATED).isAvailable()) {
            return Optional.of(providers.get(AiProviderType.SIMULATED));
        }
        return providers.values().stream().filter(AiProvider::isAvailable).findFirst();
    }

    public Optional<AiProvider> getProvider(AiProviderType type) {
        return Optional.ofNullable(providers.get(type));
    }
}
