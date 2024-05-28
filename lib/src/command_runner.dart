import 'dart:io';

import 'package:app_starter/src/logger.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'models/app_model.dart';

/// Base app_starter class to launch app creation
class CommandRunner {
  /// Method called on app creation
  Future<void> create(List<String> args) async {
    final ArgParser parser = ArgParser()
      ..addOption(
        "name",
        abbr: "n",
        defaultsTo: null,
      )
      ..addOption(
        "template",
        abbr: "t",
        defaultsTo: null,
      )
      ..addOption(
        "org",
        abbr: "o",
        defaultsTo: null,
      )
      ..addMultiOption(
        "custom-folders",
        abbr: "f",
        defaultsTo: [],
      )
      ..addFlag(
        "config",
        abbr: "c",
        negatable: false,
        defaultsTo: false,
      )
      ..addFlag(
        "save",
        abbr: "s",
        negatable: false,
        defaultsTo: false,
      )
      ..addFlag(
        "help",
        abbr: "h",
        negatable: false,
        defaultsTo: false,
      );

    final ArgResults results = parser.parse(args);

    final bool save = results["save"] as bool;
    final bool showConfig = results["config"] as bool;
    final bool showHelp = results["help"] as bool;
    final List<String> customFolders =
        results["custom-folders"] as List<String>;

    if (showHelp) {
      _showHelp();
      return;
    }

    final AppModel appModelFromConfig = AppModel.fromConfigFile();

    if (showConfig) {
      Logger.logConfigKeyValue("name", appModelFromConfig.name);
      Logger.logConfigKeyValue("organization", appModelFromConfig.organization);
      Logger.logConfigKeyValue(
          "template", appModelFromConfig.templateRepository);

      return;
    }

    final AppModel appModel = AppModel(
      name: results["name"] as String? ?? appModelFromConfig.name,
      organization:
          results["org"] as String? ?? appModelFromConfig.organization,
      templateRepository: results["template"] as String? ??
          appModelFromConfig.templateRepository,
    );

    bool hasOneFieldNull = false;

    if (appModel.name == null) {
      Logger.logError(
          "Package identifier argument not found, neither in config. --name or -n to add one.");
      hasOneFieldNull = true;
    }

    if (appModel.organization == null) {
      Logger.logError(
          "Organization identifier not found, neither in config. --org or -o to add one.");
      hasOneFieldNull = true;
    }

    if (appModel.templateRepository == null) {
      Logger.logError(
          "Template url not found, neither in config. --template or -t to use one.");
      hasOneFieldNull = true;
    }

    if (!appModel.hasValidPackageName()) {
      Logger.logError("${appModel.name} is not a dart valid package name");
      hasOneFieldNull = true;
    }

    if (hasOneFieldNull) return;

    if (save) {
      appModel.writeInConfigFile();
    }

    Logger.logInfo("Let's create ${appModel.name} application!");

    final Directory current = Directory.current;
    final String workingDirectoryPath = current.path;

    try {
      Logger.logInfo(
          "Creating flutter project using your current flutter version...");

      await Process.run(
        "flutter",
        [
          "create",
          "--org",
          appModel.organization!,
          appModel.name!,
        ],
        workingDirectory: workingDirectoryPath,
      );

      Logger.logInfo(
          "Retrieving your template from ${appModel.templateRepository}...");

      await Process.run(
        "git",
        [
          "clone",
          appModel.templateRepository!,
          "temp",
        ],
        workingDirectory: workingDirectoryPath,
      );

      final String content =
          await File(path.join(workingDirectoryPath, 'temp', 'pubspec.yaml'))
              .readAsString();
      final mapData = loadYaml(content);
      final String templatePackageName = mapData["name"];

      _copyPasteDirectory(
        path.join(workingDirectoryPath, 'temp', 'lib'),
        path.join(workingDirectoryPath, appModel.name!, 'lib'),
      );

      _copyPasteDirectory(
        path.join(workingDirectoryPath, 'temp', 'test'),
        path.join(workingDirectoryPath, appModel.name!, 'test'),
      );

      await _copyPasteFileContent(
        path.join(workingDirectoryPath, 'temp', 'pubspec.yaml'),
        path.join(workingDirectoryPath, appModel.name!, 'pubspec.yaml'),
      );

      await _copyPasteFileContent(
        path.join(workingDirectoryPath, 'temp', '.gitignore'),
        path.join(workingDirectoryPath, appModel.name!, '.gitignore'),
      );

      await _copyPasteFileContent(
        path.join(workingDirectoryPath, 'temp', 'generate_app.sh'),
        path.join(workingDirectoryPath, appModel.name!, 'generate_app.sh'),
      );

      await _changeAllInFile(
        path.join(workingDirectoryPath, appModel.name!, 'pubspec.yaml'),
        templatePackageName,
        appModel.name!,
      );

      await _changeAllInDirectory(
        path.join(workingDirectoryPath, appModel.name!, 'lib'),
        templatePackageName,
        appModel.name!,
      );

      await _changeAllInDirectory(
        path.join(workingDirectoryPath, appModel.name!, 'test'),
        templatePackageName,
        appModel.name!,
      );

      if (customFolders.isNotEmpty) {
        for (String customFolder in customFolders) {
          _copyPasteDirectory(
            path.join(workingDirectoryPath, 'temp', customFolder),
            path.join(workingDirectoryPath, appModel.name!, customFolder),
          );

          await _changeAllInDirectory(
            path.join(workingDirectoryPath, appModel.name!, customFolder),
            templatePackageName,
            appModel.name!,
          );
        }
      }

      await Process.run(
        "flutter",
        [
          "pub",
          "get",
        ],
        workingDirectory: path.join(workingDirectoryPath, appModel.name!),
      );

      Logger.logInfo("Deleting temp files used for generation...");

      await Directory(path.join(workingDirectoryPath, 'temp'))
          .delete(recursive: true);

      Logger.logInfo("You are good to go! :)", lineBreak: true);
    } catch (error) {
      Logger.logError("Error creating project: $error");

      await Directory(path.join(workingDirectoryPath, appModel.name!))
          .delete(recursive: true);
      await Directory(path.join(workingDirectoryPath, 'temp'))
          .delete(recursive: true);
    }
  }

  /// Copy all the content of [sourceFilePath] and paste it in [targetFilePath]
  Future<void> _copyPasteFileContent(
      String sourceFilePath, String targetFilePath) async {
    try {
      final File sourceFile = File(sourceFilePath);
      final File targetFile = File(targetFilePath);

      final String sourceContent = await sourceFile.readAsString();
      await targetFile.writeAsString(sourceContent);
    } catch (error) {
      Logger.logError("Error copying file contents: $error");
    }
  }

  /// Copy all the content of [sourceDirPath] and paste it in [targetDirPath]
  void _copyPasteDirectory(String sourceDirPath, String targetDirPath) {
    final Directory sourceDir = Directory(sourceDirPath);
    final Directory targetDir = Directory(targetDirPath);

    if (!sourceDir.existsSync()) {
      Logger.logWarning("Source directory does not exist: $sourceDirPath");
      return;
    }

    if (targetDir.existsSync()) {
      targetDir.deleteSync(recursive: true);
    }

    targetDir.createSync(recursive: true);

    for (var entity in sourceDir.listSync(recursive: true)) {
      if (entity is Directory) {
        final newDirectory = Directory(path.join(
            targetDir.path, path.relative(entity.path, from: sourceDir.path)));
        newDirectory.createSync(recursive: true);
      } else if (entity is File) {
        final newFile = File(path.join(
            targetDir.path, path.relative(entity.path, from: sourceDir.path)));
        newFile.writeAsBytesSync(entity.readAsBytesSync());
      }
    }
  }

  /// Update recursively all imports in [directoryPath] from [oldPackageName] to [newPackageName]
  Future<void> _changeAllInDirectory(String directoryPath,
      String oldPackageName, String newPackageName) async {
    final Directory directory = Directory(directoryPath);
    final String dirName = path.basename(directoryPath);
    if (directory.existsSync()) {
      final List<FileSystemEntity> files = directory.listSync(recursive: true);
      await Future.forEach(
        files,
        (FileSystemEntity fileSystemEntity) async {
          if (fileSystemEntity is File) {
            await _changeAllInFile(
                fileSystemEntity.path, oldPackageName, newPackageName);
          }
        },
      );
      Logger.logInfo(
          "All files in $dirName updated with new package name ($newPackageName)");
    } else {
      Logger.logWarning(
          "Missing directory $dirName in your template, it will be ignored");
    }
  }

  /// Update recursively all imports in [filePath] from [oldPackageName] to [newPackageName]
  Future<void> _changeAllInFile(
      String filePath, String oldValue, String newValue) async {
    try {
      final File file = File(filePath);
      final String content = await file.readAsString();
      if (content.contains(oldValue)) {
        final String newContent = content.replaceAll(oldValue, newValue);
        await file.writeAsString(newContent);
      }
    } catch (error) {
      Logger.logError("Error updating file $filePath: $error");
    }
  }

  /// Simply print help message
  void _showHelp() {
    print("""
    
usage: app_starter [--save] [--name <name>] [--org <org>] [--template <template>] [--custom-folders <folder1,folder2,...>] [--config]

* Abbreviations:

--name      |  -n
--org       |  -o
--template  |  -t
--custom-folders |  -f
--save      |  -s
--config    |  -c

* Add information about the app and the template:
  
name       ->       indicates the package identifier (ex: toto)
org        ->       indicates the organization identifier (ex: io.example)
template   ->       indicates the template repository (ex: https://github.com/ThomasEcalle/flappy_template)
custom-folders ->    indicates custom folder paths to be included in the template (ex: assets,scripts)

* Store default information for future usages:

save       ->       save information in config file in order to have default configuration values

For example, running : app_starter --save -n toto -o io.example -t https://github.com/ThomasEcalle/flappy_template

This will store these information in configuration file.
That way, next time, you could for example just run : app_starter -n myapp
Organization and Template values would be taken from config.

config     ->      shows values stored in configuration file
    """);
  }
}
