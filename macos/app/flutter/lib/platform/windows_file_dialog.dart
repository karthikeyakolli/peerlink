import 'dart:io';

/// Platform-specific Windows file and folder selection utility.
/// Uses native Windows OpenFileDialog / FolderBrowserDialog via PowerShell.
class WindowsFileDialog {
  static Future<List<String>> pickFiles({String title = 'Select Files to Send'}) async {
    if (!Platform.isWindows) {
      return [];
    }

    try {
      final script = '''
[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
\$d = New-Object System.Windows.Forms.OpenFileDialog
\$d.Multiselect = \$true
\$d.Title = "$title"
if (\$d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    \$d.FileNames | ForEach-Object { [Console]::WriteLine(\$_) }
}
''';
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', script],
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isEmpty) return [];
        return output
            .split(RegExp(r'\r?\n'))
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty && File(l).existsSync())
            .toList();
      }
    } catch (_) {}

    return [];
  }

  static Future<String?> pickDirectory({String title = 'Select Folder to Send'}) async {
    if (!Platform.isWindows) {
      return null;
    }

    try {
      final script = '''
[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
\$d = New-Object System.Windows.Forms.FolderBrowserDialog
\$d.Description = "$title"
if (\$d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::WriteLine(\$d.SelectedPath)
}
''';
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', script],
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty && Directory(output).existsSync()) {
          return output;
        }
      }
    } catch (_) {}

    return null;
  }
}
