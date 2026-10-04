package org.peerlink.core.ai.provider;

import org.peerlink.core.ai.gateway.AiRequest;
import org.peerlink.core.ai.gateway.AiResponse;

import java.io.IOException;

/**
 * Common abstraction for LLM providers.
 */
public interface AiProvider {

    AiProviderType getProviderType();

    String getModelName();

    boolean isAvailable();

    AiResponse generateResponse(AiRequest request) throws IOException;
}
