//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Thu, Jan 10, 2013 11:46:36 AM
// Author: tomyeh
part of stream_plugin;

/**
 * The configurer for logging.
 * If you prefer to configure the logging directly, assign your own implementation
 * and assign it to [loggingConfigurer] before instantiates the Stream server.
 */
abstract class LoggingConfigurer {
  /** Configure the logger.
   */
  void configure(Logger logger);
}

class _LoggingConfigurer implements LoggingConfigurer {
  //@override
  void configure(Logger logger) {
    Logger.root..level = Level.INFO
      ..on.record.clear();
    logger.on.record.add((record) {
      print("${record.time}:${record.sequenceNumber}\n"
        "${record.level}: ${record.message}");
      if (record.exceptionText != null)
        print("Exception: ${record.exceptionText}");
    });
  }
}
LoggingConfigurer loggingConfigurer = new _LoggingConfigurer();