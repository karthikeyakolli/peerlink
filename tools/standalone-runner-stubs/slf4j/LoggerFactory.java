package org.slf4j;

public final class LoggerFactory {
    private static final Logger NOOP = new Logger() {
        public void info(String msg) {}
        public void info(String format, Object arg) {}
        public void info(String format, Object arg1, Object arg2) {}
        public void info(String format, Object... arguments) {}
        public void debug(String msg) {}
        public void debug(String format, Object arg) {}
        public void debug(String format, Object arg1, Object arg2) {}
        public void debug(String format, Object... arguments) {}
        public void warn(String msg) {}
        public void warn(String format, Object arg) {}
        public void warn(String format, Object arg1, Object arg2) {}
        public void warn(String format, Object... arguments) {}
        public void error(String msg) {}
        public void error(String format, Object arg) {}
        public void error(String format, Object arg1, Object arg2) {}
        public void error(String format, Object... arguments) {}
        public void error(String msg, Throwable t) {}
    };

    public static Logger getLogger(Class<?> clazz) {
        return NOOP;
    }

    public static Logger getLogger(String name) {
        return NOOP;
    }
}
