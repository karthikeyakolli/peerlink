package org.peerlink.core.ai.service;

import org.peerlink.core.ai.gateway.AiGateway;
import org.peerlink.core.ai.model.AiProposal;
import org.peerlink.core.ai.policy.PolicyValidationResult;
import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;
import org.peerlink.core.operation.OperationIntent;
import org.peerlink.core.operation.OperationRecord;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

/**
 * End-to-end service coordinating the AI Gateway with PeerLink's deterministic
 * policy engine, current-state revalidation, user confirmation, and OperationManager.
 *
 * ARCHITECTURAL RULE:
 * User request -> AI Gateway -> AI proposal -> Deterministic Policy Engine ->
 * Current-state revalidation -> Authorization checks -> User confirmation ->
 * Existing Operation Manager -> Execution.
 */
public class AiGatewayService {

    public interface ObjectStateResolver {
        Optional<Path> resolvePath(ObjectIdentity objectId);
        Optional<ContentHash> getCurrentHash(ObjectIdentity objectId);
    }

    public interface OperationDispatcher {
        void dispatch(OperationRecord record);
    }

    private final AiGateway gateway;
    private final ObjectStateResolver stateResolver;
    private final OperationDispatcher dispatcher;

    public AiGatewayService(AiGateway gateway, ObjectStateResolver stateResolver, OperationDispatcher dispatcher) {
        this.gateway = Objects.requireNonNull(gateway, "gateway is required");
        this.stateResolver = Objects.requireNonNull(stateResolver, "stateResolver is required");
        this.dispatcher = Objects.requireNonNull(dispatcher, "dispatcher is required");
    }

    public AiGateway getGateway() {
        return gateway;
    }

    /**
     * Executes a full proposal lifecycle through policy evaluation,
     * current-state revalidation, and user confirmation.
     */
    public boolean executeProposal(AiProposal proposal, boolean userConfirmed) throws IOException {
        Objects.requireNonNull(proposal, "proposal is required");

        // 1. Deterministic Policy Evaluation
        PolicyValidationResult policyResult = gateway.validateProposal(proposal);
        if (!policyResult.isPermissibleWithUserConsent()) {
            throw new SecurityException("AI proposal rejected by deterministic policy: " + policyResult.getReason());
        }

        // 2. User Confirmation Check
        if (proposal.isRequiresUserConfirmation() && !userConfirmed) {
            // User rejected or has not yet approved
            return false;
        }

        // 3. Current-State Revalidation
        // Check that target objects still exist on disk and hashes have not mutated
        for (ObjectIdentity objId : proposal.getTargetObjectIds()) {
            Optional<Path> pathOpt = stateResolver.resolvePath(objId);
            if (pathOpt.isEmpty() || !Files.exists(pathOpt.get())) {
                throw new IOException("Current-state revalidation failed: Object " + objId + " no longer exists or was moved.");
            }

            // Verify content hash continuity if expected hash was declared
            ContentHash expectedHash = proposal.getExpectedHashes().get(objId);
            if (expectedHash != null) {
                Optional<ContentHash> currentHashOpt = stateResolver.getCurrentHash(objId);
                if (currentHashOpt.isEmpty() || !currentHashOpt.get().equals(expectedHash)) {
                    throw new IOException("Current-state revalidation failed: Content hash mutated since AI proposal generation.");
                }
            }
        }

        // 4. Map to Existing Deterministic Operation Record
        OperationIntent intent = proposal.getMappedIntent() != null ? proposal.getMappedIntent() : OperationIntent.SEND;
        List<String> targetIds = new ArrayList<>();
        for (ObjectIdentity oid : proposal.getTargetObjectIds()) {
            targetIds.add(oid.getValue());
        }

        OperationRecord record = OperationRecord.create(
                "op_" + UUID.randomUUID(),
                intent,
                "local_peer",
                targetIds,
                "idemp_" + proposal.getProposalId()
        );

        // 5. Dispatch to existing OperationManager
        dispatcher.dispatch(record);
        return true;
    }
}
