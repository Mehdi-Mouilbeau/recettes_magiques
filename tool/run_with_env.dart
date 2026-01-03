import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final file = File('apikey.json');
  if (!await file.exists()) {
    stderr.writeln('Missing apikey.json (not committed).');
    exit(1);
  }

  final env = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

  final flutterArgs = [
    'run',
    '-d',
    'chrome', // ou 'windows' ou 'edge'
    '--dart-define=WEB_API_KEY=${env['WEB_API_KEY']}',
    '--dart-define=ANDROID_API_KEY=${env['ANDROID_API_KEY']}',
    '--dart-define=IOS_API_KEY=${env['IOS_API_KEY']}',
    ...args,
  ];

  final flutterCmd = Platform.isWindows ? 'flutter.bat' : 'flutter';
  final p = await Process.start(flutterCmd, flutterArgs,
      mode: ProcessStartMode.inheritStdio);

  exit(await p.exitCode);
}
