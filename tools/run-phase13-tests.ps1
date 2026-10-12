$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot | Split-Path -Parent
Set-Location $RepoRoot

$outDir = Join-Path $env:TEMP "phase13_test_out_$PID"
$stubDir = Join-Path $env:TEMP "phase13_stubs_$PID"
$argFile = Join-Path $env:TEMP "phase13_srcs_$PID.txt"

try {
    if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
    if (Test-Path $stubDir) { Remove-Item -Recurse -Force $stubDir }
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    
    $protoPkgDir = Join-Path $stubDir "org\peerlink\protocol\v1"
    New-Item -ItemType Directory -Path $protoPkgDir -Force | Out-Null

    # Generate lightweight standalone protocol stubs
    Set-Content -Path (Join-Path $protoPkgDir "AccessScope.java") -Value @'
package org.peerlink.protocol.v1;

public enum AccessScope {
    ACCESS_SCOPE_UNSPECIFIED(0),
    ACCESS_SCOPE_READ_METADATA(1),
    ACCESS_SCOPE_BROWSE(2),
    ACCESS_SCOPE_SEARCH(3),
    ACCESS_SCOPE_PREVIEW(4),
    ACCESS_SCOPE_DOWNLOAD(5),
    ACCESS_SCOPE_FULL(6),
    UNRECOGNIZED(-1);

    private final int value;
    AccessScope(int value) { this.value = value; }
    public final int getNumber() { return value; }
    public static AccessScope forNumber(int value) {
        for (AccessScope s : values()) if (s.value == value) return s;
        return null;
    }
}
'@

    Set-Content -Path (Join-Path $protoPkgDir "SharePermission.java") -Value @'
package org.peerlink.protocol.v1;

public enum SharePermission {
    SHARE_PERMISSION_UNSPECIFIED(0),
    SHARE_PERMISSION_READ_METADATA(1),
    SHARE_PERMISSION_BROWSE(2),
    SHARE_PERMISSION_SEARCH(3),
    SHARE_PERMISSION_PREVIEW(4),
    SHARE_PERMISSION_DOWNLOAD(5),
    SHARE_PERMISSION_FULL(6),
    UNRECOGNIZED(-1);

    private final int value;
    SharePermission(int value) { this.value = value; }
    public final int getNumber() { return value; }
    public static SharePermission forNumber(int value) {
        for (SharePermission s : values()) if (s.value == value) return s;
        return null;
    }
}
'@

    Set-Content -Path (Join-Path $protoPkgDir "ShareType.java") -Value @'
package org.peerlink.protocol.v1;

public enum ShareType {
    SHARE_TYPE_UNSPECIFIED(0),
    SHARE_TYPE_PEER_SPECIFIC(1),
    SHARE_TYPE_TEMPORARY(2),
    SHARE_TYPE_ONE_TIME(3),
    SHARE_TYPE_GUEST(4),
    SHARE_TYPE_QR(5),
    UNRECOGNIZED(-1);

    private final int value;
    ShareType(int value) { this.value = value; }
    public final int getNumber() { return value; }
    public static ShareType forNumber(int value) {
        for (ShareType s : values()) if (s.value == value) return s;
        return null;
    }
}
'@

    Set-Content -Path (Join-Path $protoPkgDir "AccessRequestType.java") -Value @'
package org.peerlink.protocol.v1;

public enum AccessRequestType {
    ACCESS_REQUEST_TYPE_UNSPECIFIED(0),
    ACCESS_REQUEST_TYPE_LIST(1),
    ACCESS_REQUEST_TYPE_METADATA(2),
    ACCESS_REQUEST_TYPE_SEARCH(3),
    ACCESS_REQUEST_TYPE_PREVIEW(4),
    ACCESS_REQUEST_TYPE_ARCHIVE_INSPECT(5),
    ACCESS_REQUEST_TYPE_DOWNLOAD(6),
    UNRECOGNIZED(-1);

    private final int value;
    AccessRequestType(int value) { this.value = value; }
    public final int getNumber() { return value; }
    public static AccessRequestType forNumber(int value) {
        for (AccessRequestType s : values()) if (s.value == value) return s;
        return null;
    }
}
'@

    Set-Content -Path (Join-Path $protoPkgDir "ObjectType.java") -Value @'
package org.peerlink.protocol.v1;

public enum ObjectType {
    OBJECT_TYPE_UNSPECIFIED(0),
    OBJECT_TYPE_FILE(1),
    OBJECT_TYPE_DIRECTORY(2),
    OBJECT_TYPE_SYMLINK(3),
    UNRECOGNIZED(-1);

    private final int value;
    ObjectType(int value) { this.value = value; }
    public final int getNumber() { return value; }
    public static ObjectType forNumber(int value) {
        for (ObjectType s : values()) if (s.value == value) return s;
        return null;
    }
}
'@

    Set-Content -Path (Join-Path $protoPkgDir "ObjectId.java") -Value @'
package org.peerlink.protocol.v1;

public final class ObjectId {
    private final String value;
    private ObjectId(String value) { this.value = value != null ? value : ""; }
    public String getValue() { return value; }
    public static Builder newBuilder() { return new Builder(); }
    public static final class Builder {
        private String value = "";
        public Builder setValue(String val) { this.value = val; return this; }
        public ObjectId build() { return new ObjectId(value); }
    }
}
'@

    Set-Content -Path (Join-Path $protoPkgDir "ArchiveEntryDescriptor.java") -Value @'
package org.peerlink.protocol.v1;

public final class ArchiveEntryDescriptor {
    private final String entryPath;
    private final long uncompressedSizeBytes;
    private final long compressedSizeBytes;
    private final boolean isDirectory;
    private final long modifiedTimeUtcMs;
    private final boolean isSafe;
    private final String warning;

    private ArchiveEntryDescriptor(Builder b) {
        this.entryPath = b.entryPath;
        this.uncompressedSizeBytes = b.uncompressedSizeBytes;
        this.compressedSizeBytes = b.compressedSizeBytes;
        this.isDirectory = b.isDirectory;
        this.modifiedTimeUtcMs = b.modifiedTimeUtcMs;
        this.isSafe = b.isSafe;
        this.warning = b.warning;
    }

    public String getEntryPath() { return entryPath; }
    public long getUncompressedSizeBytes() { return uncompressedSizeBytes; }
    public long getCompressedSizeBytes() { return compressedSizeBytes; }
    public boolean getIsDirectory() { return isDirectory; }
    public long getModifiedTimeUtcMs() { return modifiedTimeUtcMs; }
    public boolean getIsSafe() { return isSafe; }
    public String getWarning() { return warning; }

    public static Builder newBuilder() { return new Builder(); }

    public static final class Builder {
        private String entryPath = "";
        private long uncompressedSizeBytes = 0;
        private long compressedSizeBytes = 0;
        private boolean isDirectory = false;
        private long modifiedTimeUtcMs = 0;
        private boolean isSafe = true;
        private String warning = "";

        public Builder setEntryPath(String p) { this.entryPath = p; return this; }
        public Builder setUncompressedSizeBytes(long s) { this.uncompressedSizeBytes = s; return this; }
        public Builder setCompressedSizeBytes(long s) { this.compressedSizeBytes = s; return this; }
        public Builder setIsDirectory(boolean d) { this.isDirectory = d; return this; }
        public Builder setModifiedTimeUtcMs(long m) { this.modifiedTimeUtcMs = m; return this; }
        public Builder setIsSafe(boolean s) { this.isSafe = s; return this; }
        public Builder setWarning(String w) { this.warning = w; return this; }
        public ArchiveEntryDescriptor build() { return new ArchiveEntryDescriptor(this); }
    }
}
'@

    Set-Content -Path (Join-Path $protoPkgDir "RemoteObjectReference.java") -Value @'
package org.peerlink.protocol.v1;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

public final class RemoteObjectReference {
    private final ObjectId objectId;
    private final String relativePath;
    private final String displayName;
    private final ObjectType objectType;
    private final long byteSize;
    private final String mimeType;
    private final long modifiedTimeUtcMs;
    private final boolean isSymlink;
    private final boolean isExecutable;
    private final boolean isPreviewable;
    private final boolean isHidden;
    private final Map<String, String> attributes;

    private RemoteObjectReference(Builder b) {
        this.objectId = b.objectId;
        this.relativePath = b.relativePath;
        this.displayName = b.displayName;
        this.objectType = b.objectType;
        this.byteSize = b.byteSize;
        this.mimeType = b.mimeType;
        this.modifiedTimeUtcMs = b.modifiedTimeUtcMs;
        this.isSymlink = b.isSymlink;
        this.isExecutable = b.isExecutable;
        this.isPreviewable = b.isPreviewable;
        this.isHidden = b.isHidden;
        this.attributes = Collections.unmodifiableMap(new HashMap<>(b.attributes));
    }

    public ObjectId getObjectId() { return objectId; }
    public String getRelativePath() { return relativePath; }
    public String getDisplayName() { return displayName; }
    public ObjectType getObjectType() { return objectType; }
    public long getByteSize() { return byteSize; }
    public String getMimeType() { return mimeType; }
    public long getModifiedTimeUtcMs() { return modifiedTimeUtcMs; }
    public boolean getIsSymlink() { return isSymlink; }
    public boolean getIsExecutable() { return isExecutable; }
    public boolean getIsPreviewable() { return isPreviewable; }
    public boolean getIsHidden() { return isHidden; }
    public Map<String, String> getAttributesMap() { return attributes; }

    public static Builder newBuilder() { return new Builder(); }

    public static final class Builder {
        private ObjectId objectId;
        private String relativePath = "";
        private String displayName = "";
        private ObjectType objectType = ObjectType.OBJECT_TYPE_UNSPECIFIED;
        private long byteSize = 0;
        private String mimeType = "";
        private long modifiedTimeUtcMs = 0;
        private boolean isSymlink = false;
        private boolean isExecutable = false;
        private boolean isPreviewable = false;
        private boolean isHidden = false;
        private Map<String, String> attributes = new HashMap<>();

        public Builder setObjectId(ObjectId id) { this.objectId = id; return this; }
        public Builder setRelativePath(String p) { this.relativePath = p; return this; }
        public Builder setDisplayName(String d) { this.displayName = d; return this; }
        public Builder setObjectType(ObjectType t) { this.objectType = t; return this; }
        public Builder setByteSize(long s) { this.byteSize = s; return this; }
        public Builder setMimeType(String m) { this.mimeType = m; return this; }
        public Builder setModifiedTimeUtcMs(long m) { this.modifiedTimeUtcMs = m; return this; }
        public Builder setIsSymlink(boolean s) { this.isSymlink = s; return this; }
        public Builder setIsExecutable(boolean e) { this.isExecutable = e; return this; }
        public Builder setIsPreviewable(boolean p) { this.isPreviewable = p; return this; }
        public Builder setIsHidden(boolean h) { this.isHidden = h; return this; }
        public Builder putAllAttributes(Map<String, String> attrs) { if (attrs != null) this.attributes.putAll(attrs); return this; }
        public RemoteObjectReference build() { return new RemoteObjectReference(this); }
    }
}
'@

    $stubFiles = Get-ChildItem -Path $stubDir -Recurse -Filter "*.java" | ForEach-Object { $_.FullName }

    $srcs = @(
        $stubFiles
        "core\src\main\java\org\peerlink\core\access\ShareDefinition.java"
        "core\src\main\java\org\peerlink\core\access\ShareManager.java"
        "core\src\main\java\org\peerlink\core\access\AccessGrant.java"
        "core\src\main\java\org\peerlink\core\access\PathSandboxValidator.java"
        "core\src\main\java\org\peerlink\core\access\SafePreviewEngine.java"
        "core\src\main\java\org\peerlink\core\access\BoundedFileReader.java"
        "core\src\main\java\org\peerlink\core\access\SafeDestinationHandler.java"
        "core\src\main\java\org\peerlink\core\access\CancellationToken.java"
        "core\src\main\java\org\peerlink\core\access\AccessAuditRecord.java"
        "core\src\main\java\org\peerlink\core\access\AccessAuditJournal.java"
        "core\src\main\java\org\peerlink\core\access\RemoteFolderBrowser.java"
        "core\src\main\java\org\peerlink\core\access\RemoteSearchEngine.java"
        "core\src\main\java\org\peerlink\core\access\ArchiveInspector.java"
        "core\src\main\java\org\peerlink\core\sharing\ShareCapability.java"
        "core\src\main\java\org\peerlink\core\sharing\ShareRevocationRecord.java"
        "core\src\main\java\org\peerlink\core\sharing\OneTimeConsumptionTracker.java"
        "core\src\test\java\org\peerlink\core\access\Phase13StandaloneTestRunner.java"
    )

    Set-Content -Path $argFile -Value ($srcs -join "`n")

    Write-Host "Compiling Phase 13 sources with javac..." -ForegroundColor Yellow
    & javac -d $outDir "@$argFile"
    if ($LASTEXITCODE -ne 0) {
        throw "Compilation failed with exit code $LASTEXITCODE"
    }

    Write-Host "Running Phase 13 Standalone Test Suite..." -ForegroundColor Yellow
    & java -cp $outDir org.peerlink.core.access.Phase13StandaloneTestRunner
    if ($LASTEXITCODE -ne 0) {
        throw "Test execution failed with exit code $LASTEXITCODE"
    }
} finally {
    Remove-Item -Recurse -Force $outDir -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $stubDir -ErrorAction SilentlyContinue
    Remove-Item -Force $argFile -ErrorAction SilentlyContinue
}
