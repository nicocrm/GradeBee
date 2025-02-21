import 'package:logging/logging.dart';

class SimpleLogger {
  final Logger logger;

  SimpleLogger(this.logger);

  void log(String message) {
    logger.info(message);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    logger.severe(message, error, stackTrace);
  }
}

SimpleLogger setupLogging(String name, [dynamic context]) {
  Logger.root.level = Level.FINER;
  final onLog = context == null ? print : context.log;
  final onError = context == null ? print : context.error;
  Logger.root.onRecord.listen((LogRecord record) {
    switch (record.level) {
      case Level.WARNING:
      case Level.SEVERE:
        final errorMessage = [
          record.message,
          if (record.error != null) 'Error: ${record.error}',
          if (record.stackTrace != null) 'Stack trace:\n${record.stackTrace}',
        ].join('\n');
        onError(errorMessage);
        break;
      default:
        onLog(record.message);
        break;
    }
  });
  return SimpleLogger(Logger(name));
}
