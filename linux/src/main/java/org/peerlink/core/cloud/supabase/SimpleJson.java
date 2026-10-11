package org.peerlink.core.cloud.supabase;

import java.util.*;

/**
 * Lightweight, zero-dependency JSON parser and serializer for the PeerLink Supabase adapter.
 * Supports strings, numbers, booleans, null, arrays, and key-value maps.
 */
public final class SimpleJson {

    private SimpleJson() {}

    public static String stringify(Object obj) {
        StringBuilder sb = new StringBuilder();
        serialize(obj, sb);
        return sb.toString();
    }

    @SuppressWarnings("unchecked")
    private static void serialize(Object obj, StringBuilder sb) {
        if (obj == null) {
            sb.append("null");
        } else if (obj instanceof String) {
            sb.append('"').append(escape((String) obj)).append('"');
        } else if (obj instanceof Number || obj instanceof Boolean) {
            sb.append(obj.toString());
        } else if (obj instanceof Map) {
            Map<?, ?> map = (Map<?, ?>) obj;
            sb.append('{');
            boolean first = true;
            for (Map.Entry<?, ?> entry : map.entrySet()) {
                if (!first) sb.append(',');
                first = false;
                sb.append('"').append(escape(String.valueOf(entry.getKey()))).append("\":");
                serialize(entry.getValue(), sb);
            }
            sb.append('}');
        } else if (obj instanceof Collection) {
            Collection<?> col = (Collection<?>) obj;
            sb.append('[');
            boolean first = true;
            for (Object item : col) {
                if (!first) sb.append(',');
                first = false;
                serialize(item, sb);
            }
            sb.append(']');
        } else if (obj instanceof Object[]) {
            serialize(Arrays.asList((Object[]) obj), sb);
        } else {
            sb.append('"').append(escape(obj.toString())).append('"');
        }
    }

    private static String escape(String s) {
        StringBuilder sb = new StringBuilder(s.length() + 8);
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"': sb.append("\\\""); break;
                case '\\': sb.append("\\\\"); break;
                case '\b': sb.append("\\b"); break;
                case '\f': sb.append("\\f"); break;
                case '\n': sb.append("\\n"); break;
                case '\r': sb.append("\\r"); break;
                case '\t': sb.append("\\t"); break;
                default:
                    if (c < 0x20) {
                        sb.append(String.format("\\u%04x", (int) c));
                    } else {
                        sb.append(c);
                    }
                    break;
            }
        }
        return sb.toString();
    }

    public static Object parse(String json) {
        if (json == null) return null;
        json = json.trim();
        if (json.isEmpty()) return null;
        Parser parser = new Parser(json);
        return parser.parseValue();
    }

    @SuppressWarnings("unchecked")
    public static Map<String, Object> parseObject(String json) {
        Object res = parse(json);
        if (res instanceof Map) {
            return (Map<String, Object>) res;
        }
        return Collections.emptyMap();
    }

    @SuppressWarnings("unchecked")
    public static List<Object> parseArray(String json) {
        Object res = parse(json);
        if (res instanceof List) {
            return (List<Object>) res;
        }
        return Collections.emptyList();
    }

    private static final class Parser {
        private final String src;
        private int idx = 0;

        Parser(String src) {
            this.src = src;
        }

        private void skipWhitespace() {
            while (idx < src.length() && Character.isWhitespace(src.charAt(idx))) {
                idx++;
            }
        }

        private char peek() {
            skipWhitespace();
            if (idx >= src.length()) return '\0';
            return src.charAt(idx);
        }

        private char next() {
            skipWhitespace();
            if (idx >= src.length()) return '\0';
            return src.charAt(idx++);
        }

        Object parseValue() {
            char c = peek();
            if (c == '{') return parseObject();
            if (c == '[') return parseArray();
            if (c == '"') return parseString();
            if (c == 't' || c == 'f') return parseBoolean();
            if (c == 'n') return parseNull();
            if (c == '-' || (c >= '0' && c <= '9')) return parseNumber();
            throw new IllegalArgumentException("Unexpected JSON token '" + c + "' at position " + idx);
        }

        private Map<String, Object> parseObject() {
            Map<String, Object> map = new LinkedHashMap<>();
            next(); // consume '{'
            skipWhitespace();
            if (peek() == '}') {
                next();
                return map;
            }

            while (true) {
                skipWhitespace();
                if (peek() != '"') {
                    throw new IllegalArgumentException("Expected string key in object at position " + idx);
                }
                String key = parseString();
                skipWhitespace();
                char colon = next();
                if (colon != ':') {
                    throw new IllegalArgumentException("Expected ':' after key at position " + idx);
                }
                Object val = parseValue();
                map.put(key, val);

                skipWhitespace();
                char delim = peek();
                if (delim == '}') {
                    next();
                    break;
                } else if (delim == ',') {
                    next();
                } else {
                    throw new IllegalArgumentException("Expected ',' or '}' at position " + idx);
                }
            }
            return map;
        }

        private List<Object> parseArray() {
            List<Object> list = new ArrayList<>();
            next(); // consume '['
            skipWhitespace();
            if (peek() == ']') {
                next();
                return list;
            }

            while (true) {
                list.add(parseValue());
                skipWhitespace();
                char delim = peek();
                if (delim == ']') {
                    next();
                    break;
                } else if (delim == ',') {
                    next();
                } else {
                    throw new IllegalArgumentException("Expected ',' or ']' in array at position " + idx);
                }
            }
            return list;
        }

        private String parseString() {
            next(); // consume opening quote '"'
            StringBuilder sb = new StringBuilder();
            while (idx < src.length()) {
                char c = src.charAt(idx++);
                if (c == '"') {
                    return sb.toString();
                }
                if (c == '\\') {
                    if (idx >= src.length()) {
                        throw new IllegalArgumentException("Unterminated escape sequence in string");
                    }
                    char esc = src.charAt(idx++);
                    switch (esc) {
                        case '"': sb.append('"'); break;
                        case '\\': sb.append('\\'); break;
                        case '/': sb.append('/'); break;
                        case 'b': sb.append('\b'); break;
                        case 'f': sb.append('\f'); break;
                        case 'n': sb.append('\n'); break;
                        case 'r': sb.append('\r'); break;
                        case 't': sb.append('\t'); break;
                        case 'u':
                            if (idx + 4 > src.length()) {
                                throw new IllegalArgumentException("Invalid unicode escape");
                            }
                            String hex = src.substring(idx, idx + 4);
                            idx += 4;
                            sb.append((char) Integer.parseInt(hex, 16));
                            break;
                        default:
                            sb.append(esc);
                            break;
                    }
                } else {
                    sb.append(c);
                }
            }
            throw new IllegalArgumentException("Unterminated string starting before position " + idx);
        }

        private Boolean parseBoolean() {
            if (src.startsWith("true", idx)) {
                idx += 4;
                return Boolean.TRUE;
            }
            if (src.startsWith("false", idx)) {
                idx += 5;
                return Boolean.FALSE;
            }
            throw new IllegalArgumentException("Invalid boolean literal at position " + idx);
        }

        private Object parseNull() {
            if (src.startsWith("null", idx)) {
                idx += 4;
                return null;
            }
            throw new IllegalArgumentException("Invalid null literal at position " + idx);
        }

        private Number parseNumber() {
            int start = idx;
            if (src.charAt(idx) == '-') idx++;
            while (idx < src.length() && Character.isDigit(src.charAt(idx))) {
                idx++;
            }
            boolean isFloating = false;
            if (idx < src.length() && src.charAt(idx) == '.') {
                isFloating = true;
                idx++;
                while (idx < src.length() && Character.isDigit(src.charAt(idx))) {
                    idx++;
                }
            }
            if (idx < src.length() && (src.charAt(idx) == 'e' || src.charAt(idx) == 'E')) {
                isFloating = true;
                idx++;
                if (idx < src.length() && (src.charAt(idx) == '+' || src.charAt(idx) == '-')) {
                    idx++;
                }
                while (idx < src.length() && Character.isDigit(src.charAt(idx))) {
                    idx++;
                }
            }
            String numStr = src.substring(start, idx);
            if (isFloating) {
                return Double.parseDouble(numStr);
            }
            try {
                return Long.parseLong(numStr);
            } catch (NumberFormatException e) {
                return Double.parseDouble(numStr);
            }
        }
    }
}
