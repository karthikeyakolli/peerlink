package org.peerlink.desktop.transport;

import io.netty.buffer.ByteBuf;
import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.ByteToMessageCodec;
import org.peerlink.protocol.v1.TransportFrame;

import java.util.List;

/**
 * Netty codec for length-delimited Protobuf TransportFrames.
 * Framing format: [4 bytes length header (big endian)] [Protobuf wire bytes]
 */
public class TransportFrameCodec extends ByteToMessageCodec<TransportFrame> {

    private static final int MAX_FRAME_SIZE = 16 * 1024 * 1024; // 16 MB

    @Override
    protected void encode(ChannelHandlerContext ctx, TransportFrame frame, ByteBuf out) {
        byte[] bytes = frame.toByteArray();
        out.writeInt(bytes.length);
        out.writeBytes(bytes);
    }

    @Override
    protected void decode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) throws Exception {
        if (in.readableBytes() < 4) {
            return;
        }

        in.markReaderIndex();
        int length = in.readInt();
        if (length < 0 || length > MAX_FRAME_SIZE) {
            throw new IllegalArgumentException("Invalid frame length: " + length);
        }

        if (in.readableBytes() < length) {
            in.resetReaderIndex();
            return;
        }

        byte[] bytes = new byte[length];
        in.readBytes(bytes);
        TransportFrame frame = TransportFrame.parseFrom(bytes);
        out.add(frame);
    }
}
