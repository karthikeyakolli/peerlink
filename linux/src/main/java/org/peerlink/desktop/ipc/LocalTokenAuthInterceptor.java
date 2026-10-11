package org.peerlink.desktop.ipc;

import io.grpc.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Local IPC authentication interceptor.
 * Critical invariant: Localhost is NOT automatically trusted!
 * Any local process attempting to call protected IPC methods without a valid token is rejected.
 */
public final class LocalTokenAuthInterceptor implements ServerInterceptor {
    private static final Logger log = LoggerFactory.getLogger(LocalTokenAuthInterceptor.class);

    public static final Metadata.Key<String> AUTH_HEADER =
            Metadata.Key.of("x-peerlink-auth-token", Metadata.ASCII_STRING_MARSHALLER);

    private final String expectedBootToken;
    private final java.util.function.Predicate<String> sessionValidator;

    public LocalTokenAuthInterceptor(String expectedBootToken) {
        this(validateToken(expectedBootToken), null);
    }

    public LocalTokenAuthInterceptor(java.util.function.Predicate<String> sessionValidator) {
        if (sessionValidator == null) {
            throw new IllegalArgumentException("Session validator cannot be null");
        }
        this.expectedBootToken = null;
        this.sessionValidator = sessionValidator;
    }

    public LocalTokenAuthInterceptor(String expectedBootToken, java.util.function.Predicate<String> sessionValidator) {
        if ((expectedBootToken == null || expectedBootToken.isBlank()) && sessionValidator == null) {
            throw new IllegalArgumentException("Either expectedBootToken or sessionValidator must be provided");
        }
        this.expectedBootToken = expectedBootToken;
        this.sessionValidator = sessionValidator;
    }

    private static String validateToken(String token) {
        if (token == null || token.isBlank()) {
            throw new IllegalArgumentException("Expected boot token cannot be null or blank");
        }
        return token;
    }

    @Override
    public <ReqT, RespT> ServerCall.Listener<ReqT> interceptCall(
            ServerCall<ReqT, RespT> call,
            Metadata headers,
            ServerCallHandler<ReqT, RespT> next) {

        String methodName = call.getMethodDescriptor().getFullMethodName();

        // The Authenticate RPC is permitted without header auth (it verifies token in request payload)
        if (methodName.endsWith("/Authenticate")) {
            return next.startCall(call, headers);
        }

        String providedToken = headers.get(AUTH_HEADER);
        if (providedToken == null || providedToken.isBlank()) {
            log.warn("Rejected unauthenticated local IPC call to {} (missing auth header)", methodName);
            call.close(Status.UNAUTHENTICATED.withDescription("Missing local IPC auth header"), new Metadata());
            return new ServerCall.Listener<>() {};
        }

        boolean valid = false;

        // 1. Check active authenticated session validator
        if (sessionValidator != null && sessionValidator.test(providedToken)) {
            valid = true;
        }

        // 2. Fallback to constant-time boot token check if configured
        if (!valid && expectedBootToken != null && !expectedBootToken.isBlank()) {
            valid = java.security.MessageDigest.isEqual(
                    providedToken.getBytes(java.nio.charset.StandardCharsets.UTF_8),
                    expectedBootToken.getBytes(java.nio.charset.StandardCharsets.UTF_8)
            );
        }

        if (!valid) {
            log.warn("Rejected unauthorized or expired local IPC call to {}", methodName);
            call.close(Status.UNAUTHENTICATED.withDescription("Invalid, unauthorized, or expired local IPC session token"), new Metadata());
            return new ServerCall.Listener<>() {};
        }

        return next.startCall(call, headers);
    }
}
