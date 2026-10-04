# PeerLink Populate Canonical Shared-Source Script
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$Canonical = Join-Path $RepoRoot "shared-source/canonical"
Write-Host "Populating canonical shared source at: $Canonical" -ForegroundColor Cyan

# 1. Core
$CoreDest = Join-Path $Canonical "core"
New-Item -ItemType Directory -Path $CoreDest -Force | Out-Null
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/model" $CoreDest/
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/identity" $CoreDest/
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/capability" $CoreDest/
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/event" $CoreDest/
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/error" $CoreDest/
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/ai" $CoreDest/
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/collaboration" $CoreDest/
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/platform" $CoreDest/

# 2. Protocol
$ProtoDest = Join-Path $Canonical "protocol"
New-Item -ItemType Directory -Path $ProtoDest -Force | Out-Null
Copy-Item -Recurse -Force "protocol/proto" $ProtoDest/
Copy-Item -Recurse -Force "protocol/generated-java" $ProtoDest/
Copy-Item -Recurse -Force "protocol/generated-dart" $ProtoDest/

# 3. Operations
$OpsDest = Join-Path $Canonical "operations"
New-Item -ItemType Directory -Path $OpsDest -Force | Out-Null
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/operation/*" $OpsDest/

# 4. Transfer
$TransferDest = Join-Path $Canonical "transfer"
New-Item -ItemType Directory -Path $TransferDest -Force | Out-Null
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/transfer/*" $TransferDest/
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/transport" $TransferDest/

# 5. Sync
$SyncDest = Join-Path $Canonical "sync"
New-Item -ItemType Directory -Path $SyncDest -Force | Out-Null
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/sync/*" $SyncDest/

# 6. Backup
$BackupDest = Join-Path $Canonical "backup"
New-Item -ItemType Directory -Path $BackupDest -Force | Out-Null
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/backup/*" $BackupDest/

# 7. Access
$AccessDest = Join-Path $Canonical "access"
New-Item -ItemType Directory -Path $AccessDest -Force | Out-Null
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/access/*" $AccessDest/

# 8. Sharing
$SharingDest = Join-Path $Canonical "sharing"
New-Item -ItemType Directory -Path $SharingDest -Force | Out-Null
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/sharing/*" $SharingDest/

# 9. Workspace
$WorkspaceDest = Join-Path $Canonical "workspace"
New-Item -ItemType Directory -Path $WorkspaceDest -Force | Out-Null
$WsSource = "core/src/main/java/org/peerlink/core/workspace"
if (Test-Path $WsSource) {
    Copy-Item -Recurse -Force "$WsSource/*" $WorkspaceDest/
} else {
    # Generate canonical workspace contract if not a separate subpackage
    $WsContent = @"
package org.peerlink.core.workspace;

import org.peerlink.core.model.PeerId;
import java.io.File;
import java.util.Objects;

public final class WorkspaceScope {
    private final String workspaceId;
    private final PeerId owner;
    private final File rootDirectory;

    public WorkspaceScope(String workspaceId, PeerId owner, File rootDirectory) {
        this.workspaceId = Objects.requireNonNull(workspaceId);
        this.owner = Objects.requireNonNull(owner);
        this.rootDirectory = Objects.requireNonNull(rootDirectory);
    }

    public String getWorkspaceId() { return workspaceId; }
    public PeerId getOwner() { return owner; }
    public File getRootDirectory() { return rootDirectory; }
}
"@
    Set-Content -Path (Join-Path $WorkspaceDest "WorkspaceScope.java") -Value $WsContent -Encoding UTF8
}

# 10. Clipboard
$ClipDest = Join-Path $Canonical "clipboard"
New-Item -ItemType Directory -Path $ClipDest -Force | Out-Null
$ClipSource = "core/src/main/java/org/peerlink/core/clipboard"
if (Test-Path $ClipSource) {
    Copy-Item -Recurse -Force "$ClipSource/*" $ClipDest/
} else {
    $ClipContent = @"
package org.peerlink.core.clipboard;

import java.util.regex.Pattern;

public final class ClipboardSanitizer {
    private static final Pattern CARD_PATTERN = Pattern.compile("\\b(?:\\d[ -]*?){13,16}\\b");
    private static final Pattern KEY_PATTERN = Pattern.compile("(?i)(?:api_key|secret|password|bearer)\\s*[:=]\\s*\\S+");

    public static boolean containsSensitiveData(String text) {
        if (text == null) return false;
        return CARD_PATTERN.matcher(text).find() || KEY_PATTERN.matcher(text).find();
    }

    public static String sanitize(String text) {
        if (text == null) return "";
        if (containsSensitiveData(text)) {
            return "[REDACTED - SENSITIVE CONTENT DETECTED]";
        }
        return text;
    }
}
"@
    Set-Content -Path (Join-Path $ClipDest "ClipboardSanitizer.java") -Value $ClipContent -Encoding UTF8
}

# 11. Compatibility
$CompatDest = Join-Path $Canonical "compatibility"
New-Item -ItemType Directory -Path $CompatDest -Force | Out-Null
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/compatibility/*" $CompatDest/

# 12. Security
$SecDest = Join-Path $Canonical "security"
New-Item -ItemType Directory -Path $SecDest -Force | Out-Null
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/security/*" $SecDest/
Copy-Item -Recurse -Force "core/src/main/java/org/peerlink/core/safety" $SecDest/

# 13. Recovery
$RecDest = Join-Path $Canonical "recovery"
New-Item -ItemType Directory -Path $RecDest -Force | Out-Null
if (Test-Path "desktop-node/src/main/java/org/peerlink/desktop/storage/StartupRecoveryManager.java") {
    Copy-Item -Force "desktop-node/src/main/java/org/peerlink/desktop/storage/StartupRecoveryManager.java" $RecDest/
}

# 14. Diagnostics
$DiagDest = Join-Path $Canonical "diagnostics"
New-Item -ItemType Directory -Path $DiagDest -Force | Out-Null
$DiagContent = @"
package org.peerlink.core.diagnostics;

import java.util.concurrent.atomic.AtomicLong;

public final class DiagnosticsCollector {
    private final AtomicLong operationsExecuted = new AtomicLong(0);
    private final AtomicLong bytesTransferred = new AtomicLong(0);
    private final AtomicLong errorsEncountered = new AtomicLong(0);

    public void recordOperation() { operationsExecuted.incrementAndGet(); }
    public void recordBytes(long bytes) { bytesTransferred.addAndGet(bytes); }
    public void recordError() { errorsEncountered.incrementAndGet(); }

    public long getOperationsExecuted() { return operationsExecuted.get(); }
    public long getBytesTransferred() { return bytesTransferred.get(); }
    public long getErrorsEncountered() { return errorsEncountered.get(); }
}
"@
Set-Content -Path (Join-Path $DiagDest "DiagnosticsCollector.java") -Value $DiagContent -Encoding UTF8

# 15. Flutter Common UI
$FlutterDest = Join-Path $Canonical "flutter"
New-Item -ItemType Directory -Path $FlutterDest -Force | Out-Null
Copy-Item -Recurse -Force "apps/peerlink-app/lib" $FlutterDest/
Copy-Item -Recurse -Force "apps/peerlink-app/test" $FlutterDest/
Copy-Item -Force "apps/peerlink-app/pubspec.yaml" $FlutterDest/
Copy-Item -Force "apps/peerlink-app/analysis_options.yaml" $FlutterDest/

Write-Host "Canonical shared source populated successfully." -ForegroundColor Green
