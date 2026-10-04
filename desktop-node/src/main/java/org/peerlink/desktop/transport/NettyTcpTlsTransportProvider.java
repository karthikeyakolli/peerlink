package org.peerlink.desktop.transport;

import io.netty.bootstrap.Bootstrap;
import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.*;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.socket.SocketChannel;
import io.netty.channel.socket.nio.NioServerSocketChannel;
import io.netty.channel.socket.nio.NioSocketChannel;
import org.peerlink.core.transport.TransportConnection;
import org.peerlink.core.transport.TransportConnectionListener;
import org.peerlink.core.transport.TransportProvider;
import org.peerlink.protocol.v1.TransportFrame;
import org.peerlink.protocol.v1.TransportType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.atomic.AtomicBoolean;

public class NettyTcpTlsTransportProvider implements TransportProvider {

    private static final Logger log = LoggerFactory.getLogger(NettyTcpTlsTransportProvider.class);
    private static final io.netty.util.AttributeKey<NettyTcpTransportConnection> CONN_KEY =
            io.netty.util.AttributeKey.valueOf(NettyTcpTlsTransportProvider.class, "PEERLINK_TCP_CONN");

    private final EventLoopGroup bossGroup;
    private final EventLoopGroup workerGroup;
    private final boolean ownsEventLoops;

    private Channel serverChannel;
    private int listeningPort = 0;
    private final AtomicBoolean isListening = new AtomicBoolean(false);

    public NettyTcpTlsTransportProvider() {
        this.bossGroup = new NioEventLoopGroup(1);
        this.workerGroup = new NioEventLoopGroup(2);
        this.ownsEventLoops = true;
    }

    public NettyTcpTlsTransportProvider(EventLoopGroup bossGroup, EventLoopGroup workerGroup) {
        this.bossGroup = bossGroup;
        this.workerGroup = workerGroup;
        this.ownsEventLoops = false;
    }

    @Override
    public TransportType getTransportType() {
        return TransportType.TRANSPORT_TYPE_DIRECT_TCP_TLS;
    }

    @Override
    public boolean isAvailable() {
        return true;
    }

    @Override
    public int getPriority() {
        return 2; // Priority 2 (fallback when QUIC is absent/unavailable)
    }

    @Override
    public void startListening(int port, TransportConnectionListener listener) throws IOException {
        if (!isListening.compareAndSet(false, true)) {
            throw new IllegalStateException("Already listening on port " + listeningPort);
        }

        try {
            ServerBootstrap b = new ServerBootstrap();
            b.group(bossGroup, workerGroup)
                    .channel(NioServerSocketChannel.class)
                    .childHandler(new ChannelInitializer<SocketChannel>() {
                        @Override
                        protected void initChannel(SocketChannel ch) {
                            NettyTcpTransportConnection connection = new NettyTcpTransportConnection(ch);
                            ch.pipeline().addLast(new TransportFrameCodec());
                            ch.pipeline().addLast(new SimpleChannelInboundHandler<TransportFrame>() {
                                @Override
                                protected void channelRead0(ChannelHandlerContext ctx, TransportFrame msg) {
                                    connection.onInboundFrame(msg);
                                }

                                @Override
                                public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) {
                                    connection.onInboundError(cause);
                                    ctx.close();
                                }
                            });
                            listener.onConnectionAccepted(connection);
                        }
                    })
                    .option(ChannelOption.SO_BACKLOG, 128)
                    .childOption(ChannelOption.SO_KEEPALIVE, true)
                    .childOption(ChannelOption.TCP_NODELAY, true);

            ChannelFuture f = b.bind(new InetSocketAddress("127.0.0.1", port)).sync();
            this.serverChannel = f.channel();
            this.listeningPort = ((InetSocketAddress) serverChannel.localAddress()).getPort();
            log.info("Netty TCP/TLS transport listening on port {}", listeningPort);
        } catch (Exception e) {
            isListening.set(false);
            throw new IOException("Failed to bind TCP server on port " + port, e);
        }
    }

    @Override
    public int getListeningPort() {
        return listeningPort;
    }

    @Override
    public CompletableFuture<TransportConnection> connectAsync(InetSocketAddress remoteAddress) {
        CompletableFuture<TransportConnection> future = new CompletableFuture<>();

        Bootstrap b = new Bootstrap();
        b.group(workerGroup)
                .channel(NioSocketChannel.class)
                .option(ChannelOption.TCP_NODELAY, true)
                .handler(new ChannelInitializer<SocketChannel>() {
                    @Override
                    protected void initChannel(SocketChannel ch) {
                        NettyTcpTransportConnection connection = new NettyTcpTransportConnection(ch);
                        ch.pipeline().addLast(new TransportFrameCodec());
                        ch.pipeline().addLast(new SimpleChannelInboundHandler<TransportFrame>() {
                            @Override
                            protected void channelRead0(ChannelHandlerContext ctx, TransportFrame msg) {
                                connection.onInboundFrame(msg);
                            }

                            @Override
                            public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) {
                                connection.onInboundError(cause);
                                ctx.close();
                            }
                        });
                        ch.attr(CONN_KEY).set(connection);
                    }
                });

        b.connect(remoteAddress).addListener((ChannelFutureListener) f -> {
            if (f.isSuccess()) {
                NettyTcpTransportConnection conn = f.channel().attr(CONN_KEY).get();
                future.complete(conn);
            } else {
                future.completeExceptionally(f.cause());
            }
        });

        return future;
    }

    @Override
    public void stopListening() {
        if (isListening.compareAndSet(true, false) && serverChannel != null) {
            serverChannel.close();
            serverChannel = null;
        }
    }

    @Override
    public void close() {
        stopListening();
        if (ownsEventLoops) {
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }
}
