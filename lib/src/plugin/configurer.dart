//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Thu, Jan 10, 2013 11:46:36 AM
// Author: tomyeh
part of stream_plugin;

/**
 * The configurer for logging.
 */
abstract class LoggingConfigurer {
  factory LoggingConfigurer() => new _LoggingConfigurer();

  /** Configure the logger.
   */
  void configure(Logger logger);
}

class _LoggingConfigurer implements LoggingConfigurer {
  @override
  void configure(Logger logger) {
    Logger.root.level = Level.INFO;
    logger.onRecord.listen(simpleLoggerHandler);
  }
}
