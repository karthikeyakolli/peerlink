package org.peerlink.core.collaboration.smart;

import java.io.Serializable;
import java.util.Objects;
import java.util.Set;

/**
 * Reusable rule template for transformations, exclusions, and destination settings.
 */
public final class TransferRecipe implements Serializable {
    private static final long serialVersionUID = 1L;

    private final String recipeId;
    private final String name;
    private final Set<String> excludeExtensions;
    private final boolean compressArchives;
    private final boolean requireMalwareScan;
    private final NetworkPolicy defaultNetworkPolicy;

    public TransferRecipe(
            String recipeId,
            String name,
            Set<String> excludeExtensions,
            boolean compressArchives,
            boolean requireMalwareScan,
            NetworkPolicy defaultNetworkPolicy
    ) {
        this.recipeId = Objects.requireNonNull(recipeId, "recipeId is required");
        this.name = Objects.requireNonNull(name, "name is required");
        this.excludeExtensions = excludeExtensions == null ? Set.of() : Set.copyOf(excludeExtensions);
        this.compressArchives = compressArchives;
        this.requireMalwareScan = requireMalwareScan;
        this.defaultNetworkPolicy = defaultNetworkPolicy != null ? defaultNetworkPolicy : NetworkPolicy.ANY;
    }

    public String getRecipeId() { return recipeId; }
    public String getName() { return name; }
    public Set<String> getExcludeExtensions() { return excludeExtensions; }
    public boolean isCompressArchives() { return compressArchives; }
    public boolean isRequireMalwareScan() { return requireMalwareScan; }
    public NetworkPolicy getDefaultNetworkPolicy() { return defaultNetworkPolicy; }
}