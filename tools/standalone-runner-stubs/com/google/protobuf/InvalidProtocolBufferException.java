package com.google.protobuf;

import java.io.IOException;

public class InvalidProtocolBufferException extends IOException {
    public InvalidProtocolBufferException(String message) {
        super(message);
    }
}
