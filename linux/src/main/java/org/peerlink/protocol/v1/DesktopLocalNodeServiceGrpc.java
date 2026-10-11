package org.peerlink.protocol.v1;

import static io.grpc.MethodDescriptor.generateFullMethodName;

/**
 */
@javax.annotation.Generated(
    value = "by gRPC proto compiler (version 1.69.0)",
    comments = "Source: peerlink/v1/ipc.proto")
@io.grpc.stub.annotations.GrpcGenerated
public final class DesktopLocalNodeServiceGrpc {

  private DesktopLocalNodeServiceGrpc() {}

  public static final java.lang.String SERVICE_NAME = "peerlink.v1.DesktopLocalNodeService";

  // Static method descriptors that strictly reflect the proto.
  private static volatile io.grpc.MethodDescriptor<org.peerlink.protocol.v1.AuthenticateIpcRequest,
      org.peerlink.protocol.v1.AuthenticateIpcResponse> getAuthenticateMethod;

  @io.grpc.stub.annotations.RpcMethod(
      fullMethodName = SERVICE_NAME + '/' + "Authenticate",
      requestType = org.peerlink.protocol.v1.AuthenticateIpcRequest.class,
      responseType = org.peerlink.protocol.v1.AuthenticateIpcResponse.class,
      methodType = io.grpc.MethodDescriptor.MethodType.UNARY)
  public static io.grpc.MethodDescriptor<org.peerlink.protocol.v1.AuthenticateIpcRequest,
      org.peerlink.protocol.v1.AuthenticateIpcResponse> getAuthenticateMethod() {
    io.grpc.MethodDescriptor<org.peerlink.protocol.v1.AuthenticateIpcRequest, org.peerlink.protocol.v1.AuthenticateIpcResponse> getAuthenticateMethod;
    if ((getAuthenticateMethod = DesktopLocalNodeServiceGrpc.getAuthenticateMethod) == null) {
      synchronized (DesktopLocalNodeServiceGrpc.class) {
        if ((getAuthenticateMethod = DesktopLocalNodeServiceGrpc.getAuthenticateMethod) == null) {
          DesktopLocalNodeServiceGrpc.getAuthenticateMethod = getAuthenticateMethod =
              io.grpc.MethodDescriptor.<org.peerlink.protocol.v1.AuthenticateIpcRequest, org.peerlink.protocol.v1.AuthenticateIpcResponse>newBuilder()
              .setType(io.grpc.MethodDescriptor.MethodType.UNARY)
              .setFullMethodName(generateFullMethodName(SERVICE_NAME, "Authenticate"))
              .setSampledToLocalTracing(true)
              .setRequestMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.AuthenticateIpcRequest.getDefaultInstance()))
              .setResponseMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.AuthenticateIpcResponse.getDefaultInstance()))
              .setSchemaDescriptor(new DesktopLocalNodeServiceMethodDescriptorSupplier("Authenticate"))
              .build();
        }
      }
    }
    return getAuthenticateMethod;
  }

  private static volatile io.grpc.MethodDescriptor<org.peerlink.protocol.v1.GetNodeStatusRequest,
      org.peerlink.protocol.v1.GetNodeStatusResponse> getGetStatusMethod;

  @io.grpc.stub.annotations.RpcMethod(
      fullMethodName = SERVICE_NAME + '/' + "GetStatus",
      requestType = org.peerlink.protocol.v1.GetNodeStatusRequest.class,
      responseType = org.peerlink.protocol.v1.GetNodeStatusResponse.class,
      methodType = io.grpc.MethodDescriptor.MethodType.UNARY)
  public static io.grpc.MethodDescriptor<org.peerlink.protocol.v1.GetNodeStatusRequest,
      org.peerlink.protocol.v1.GetNodeStatusResponse> getGetStatusMethod() {
    io.grpc.MethodDescriptor<org.peerlink.protocol.v1.GetNodeStatusRequest, org.peerlink.protocol.v1.GetNodeStatusResponse> getGetStatusMethod;
    if ((getGetStatusMethod = DesktopLocalNodeServiceGrpc.getGetStatusMethod) == null) {
      synchronized (DesktopLocalNodeServiceGrpc.class) {
        if ((getGetStatusMethod = DesktopLocalNodeServiceGrpc.getGetStatusMethod) == null) {
          DesktopLocalNodeServiceGrpc.getGetStatusMethod = getGetStatusMethod =
              io.grpc.MethodDescriptor.<org.peerlink.protocol.v1.GetNodeStatusRequest, org.peerlink.protocol.v1.GetNodeStatusResponse>newBuilder()
              .setType(io.grpc.MethodDescriptor.MethodType.UNARY)
              .setFullMethodName(generateFullMethodName(SERVICE_NAME, "GetStatus"))
              .setSampledToLocalTracing(true)
              .setRequestMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.GetNodeStatusRequest.getDefaultInstance()))
              .setResponseMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.GetNodeStatusResponse.getDefaultInstance()))
              .setSchemaDescriptor(new DesktopLocalNodeServiceMethodDescriptorSupplier("GetStatus"))
              .build();
        }
      }
    }
    return getGetStatusMethod;
  }

  private static volatile io.grpc.MethodDescriptor<org.peerlink.protocol.v1.NodeEventSubscriptionRequest,
      org.peerlink.protocol.v1.NodeEvent> getSubscribeEventsMethod;

  @io.grpc.stub.annotations.RpcMethod(
      fullMethodName = SERVICE_NAME + '/' + "SubscribeEvents",
      requestType = org.peerlink.protocol.v1.NodeEventSubscriptionRequest.class,
      responseType = org.peerlink.protocol.v1.NodeEvent.class,
      methodType = io.grpc.MethodDescriptor.MethodType.SERVER_STREAMING)
  public static io.grpc.MethodDescriptor<org.peerlink.protocol.v1.NodeEventSubscriptionRequest,
      org.peerlink.protocol.v1.NodeEvent> getSubscribeEventsMethod() {
    io.grpc.MethodDescriptor<org.peerlink.protocol.v1.NodeEventSubscriptionRequest, org.peerlink.protocol.v1.NodeEvent> getSubscribeEventsMethod;
    if ((getSubscribeEventsMethod = DesktopLocalNodeServiceGrpc.getSubscribeEventsMethod) == null) {
      synchronized (DesktopLocalNodeServiceGrpc.class) {
        if ((getSubscribeEventsMethod = DesktopLocalNodeServiceGrpc.getSubscribeEventsMethod) == null) {
          DesktopLocalNodeServiceGrpc.getSubscribeEventsMethod = getSubscribeEventsMethod =
              io.grpc.MethodDescriptor.<org.peerlink.protocol.v1.NodeEventSubscriptionRequest, org.peerlink.protocol.v1.NodeEvent>newBuilder()
              .setType(io.grpc.MethodDescriptor.MethodType.SERVER_STREAMING)
              .setFullMethodName(generateFullMethodName(SERVICE_NAME, "SubscribeEvents"))
              .setSampledToLocalTracing(true)
              .setRequestMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.NodeEventSubscriptionRequest.getDefaultInstance()))
              .setResponseMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.NodeEvent.getDefaultInstance()))
              .setSchemaDescriptor(new DesktopLocalNodeServiceMethodDescriptorSupplier("SubscribeEvents"))
              .build();
        }
      }
    }
    return getSubscribeEventsMethod;
  }

  private static volatile io.grpc.MethodDescriptor<org.peerlink.protocol.v1.RestartNodeRequest,
      org.peerlink.protocol.v1.RestartNodeResponse> getRestartMethod;

  @io.grpc.stub.annotations.RpcMethod(
      fullMethodName = SERVICE_NAME + '/' + "Restart",
      requestType = org.peerlink.protocol.v1.RestartNodeRequest.class,
      responseType = org.peerlink.protocol.v1.RestartNodeResponse.class,
      methodType = io.grpc.MethodDescriptor.MethodType.UNARY)
  public static io.grpc.MethodDescriptor<org.peerlink.protocol.v1.RestartNodeRequest,
      org.peerlink.protocol.v1.RestartNodeResponse> getRestartMethod() {
    io.grpc.MethodDescriptor<org.peerlink.protocol.v1.RestartNodeRequest, org.peerlink.protocol.v1.RestartNodeResponse> getRestartMethod;
    if ((getRestartMethod = DesktopLocalNodeServiceGrpc.getRestartMethod) == null) {
      synchronized (DesktopLocalNodeServiceGrpc.class) {
        if ((getRestartMethod = DesktopLocalNodeServiceGrpc.getRestartMethod) == null) {
          DesktopLocalNodeServiceGrpc.getRestartMethod = getRestartMethod =
              io.grpc.MethodDescriptor.<org.peerlink.protocol.v1.RestartNodeRequest, org.peerlink.protocol.v1.RestartNodeResponse>newBuilder()
              .setType(io.grpc.MethodDescriptor.MethodType.UNARY)
              .setFullMethodName(generateFullMethodName(SERVICE_NAME, "Restart"))
              .setSampledToLocalTracing(true)
              .setRequestMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.RestartNodeRequest.getDefaultInstance()))
              .setResponseMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.RestartNodeResponse.getDefaultInstance()))
              .setSchemaDescriptor(new DesktopLocalNodeServiceMethodDescriptorSupplier("Restart"))
              .build();
        }
      }
    }
    return getRestartMethod;
  }

  private static volatile io.grpc.MethodDescriptor<org.peerlink.protocol.v1.StopNodeRequest,
      org.peerlink.protocol.v1.StopNodeResponse> getStopMethod;

  @io.grpc.stub.annotations.RpcMethod(
      fullMethodName = SERVICE_NAME + '/' + "Stop",
      requestType = org.peerlink.protocol.v1.StopNodeRequest.class,
      responseType = org.peerlink.protocol.v1.StopNodeResponse.class,
      methodType = io.grpc.MethodDescriptor.MethodType.UNARY)
  public static io.grpc.MethodDescriptor<org.peerlink.protocol.v1.StopNodeRequest,
      org.peerlink.protocol.v1.StopNodeResponse> getStopMethod() {
    io.grpc.MethodDescriptor<org.peerlink.protocol.v1.StopNodeRequest, org.peerlink.protocol.v1.StopNodeResponse> getStopMethod;
    if ((getStopMethod = DesktopLocalNodeServiceGrpc.getStopMethod) == null) {
      synchronized (DesktopLocalNodeServiceGrpc.class) {
        if ((getStopMethod = DesktopLocalNodeServiceGrpc.getStopMethod) == null) {
          DesktopLocalNodeServiceGrpc.getStopMethod = getStopMethod =
              io.grpc.MethodDescriptor.<org.peerlink.protocol.v1.StopNodeRequest, org.peerlink.protocol.v1.StopNodeResponse>newBuilder()
              .setType(io.grpc.MethodDescriptor.MethodType.UNARY)
              .setFullMethodName(generateFullMethodName(SERVICE_NAME, "Stop"))
              .setSampledToLocalTracing(true)
              .setRequestMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.StopNodeRequest.getDefaultInstance()))
              .setResponseMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.StopNodeResponse.getDefaultInstance()))
              .setSchemaDescriptor(new DesktopLocalNodeServiceMethodDescriptorSupplier("Stop"))
              .build();
        }
      }
    }
    return getStopMethod;
  }

  private static volatile io.grpc.MethodDescriptor<org.peerlink.protocol.v1.InitiateSendRequest,
      org.peerlink.protocol.v1.InitiateSendResponse> getInitiateSendMethod;

  @io.grpc.stub.annotations.RpcMethod(
      fullMethodName = SERVICE_NAME + '/' + "InitiateSend",
      requestType = org.peerlink.protocol.v1.InitiateSendRequest.class,
      responseType = org.peerlink.protocol.v1.InitiateSendResponse.class,
      methodType = io.grpc.MethodDescriptor.MethodType.UNARY)
  public static io.grpc.MethodDescriptor<org.peerlink.protocol.v1.InitiateSendRequest,
      org.peerlink.protocol.v1.InitiateSendResponse> getInitiateSendMethod() {
    io.grpc.MethodDescriptor<org.peerlink.protocol.v1.InitiateSendRequest, org.peerlink.protocol.v1.InitiateSendResponse> getInitiateSendMethod;
    if ((getInitiateSendMethod = DesktopLocalNodeServiceGrpc.getInitiateSendMethod) == null) {
      synchronized (DesktopLocalNodeServiceGrpc.class) {
        if ((getInitiateSendMethod = DesktopLocalNodeServiceGrpc.getInitiateSendMethod) == null) {
          DesktopLocalNodeServiceGrpc.getInitiateSendMethod = getInitiateSendMethod =
              io.grpc.MethodDescriptor.<org.peerlink.protocol.v1.InitiateSendRequest, org.peerlink.protocol.v1.InitiateSendResponse>newBuilder()
              .setType(io.grpc.MethodDescriptor.MethodType.UNARY)
              .setFullMethodName(generateFullMethodName(SERVICE_NAME, "InitiateSend"))
              .setSampledToLocalTracing(true)
              .setRequestMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.InitiateSendRequest.getDefaultInstance()))
              .setResponseMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.InitiateSendResponse.getDefaultInstance()))
              .setSchemaDescriptor(new DesktopLocalNodeServiceMethodDescriptorSupplier("InitiateSend"))
              .build();
        }
      }
    }
    return getInitiateSendMethod;
  }

  private static volatile io.grpc.MethodDescriptor<org.peerlink.protocol.v1.CancelTransferRequest,
      org.peerlink.protocol.v1.CancelTransferResponse> getCancelTransferMethod;

  @io.grpc.stub.annotations.RpcMethod(
      fullMethodName = SERVICE_NAME + '/' + "CancelTransfer",
      requestType = org.peerlink.protocol.v1.CancelTransferRequest.class,
      responseType = org.peerlink.protocol.v1.CancelTransferResponse.class,
      methodType = io.grpc.MethodDescriptor.MethodType.UNARY)
  public static io.grpc.MethodDescriptor<org.peerlink.protocol.v1.CancelTransferRequest,
      org.peerlink.protocol.v1.CancelTransferResponse> getCancelTransferMethod() {
    io.grpc.MethodDescriptor<org.peerlink.protocol.v1.CancelTransferRequest, org.peerlink.protocol.v1.CancelTransferResponse> getCancelTransferMethod;
    if ((getCancelTransferMethod = DesktopLocalNodeServiceGrpc.getCancelTransferMethod) == null) {
      synchronized (DesktopLocalNodeServiceGrpc.class) {
        if ((getCancelTransferMethod = DesktopLocalNodeServiceGrpc.getCancelTransferMethod) == null) {
          DesktopLocalNodeServiceGrpc.getCancelTransferMethod = getCancelTransferMethod =
              io.grpc.MethodDescriptor.<org.peerlink.protocol.v1.CancelTransferRequest, org.peerlink.protocol.v1.CancelTransferResponse>newBuilder()
              .setType(io.grpc.MethodDescriptor.MethodType.UNARY)
              .setFullMethodName(generateFullMethodName(SERVICE_NAME, "CancelTransfer"))
              .setSampledToLocalTracing(true)
              .setRequestMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.CancelTransferRequest.getDefaultInstance()))
              .setResponseMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.CancelTransferResponse.getDefaultInstance()))
              .setSchemaDescriptor(new DesktopLocalNodeServiceMethodDescriptorSupplier("CancelTransfer"))
              .build();
        }
      }
    }
    return getCancelTransferMethod;
  }

  private static volatile io.grpc.MethodDescriptor<org.peerlink.protocol.v1.PauseTransferRequest,
      org.peerlink.protocol.v1.PauseTransferResponse> getPauseTransferMethod;

  @io.grpc.stub.annotations.RpcMethod(
      fullMethodName = SERVICE_NAME + '/' + "PauseTransfer",
      requestType = org.peerlink.protocol.v1.PauseTransferRequest.class,
      responseType = org.peerlink.protocol.v1.PauseTransferResponse.class,
      methodType = io.grpc.MethodDescriptor.MethodType.UNARY)
  public static io.grpc.MethodDescriptor<org.peerlink.protocol.v1.PauseTransferRequest,
      org.peerlink.protocol.v1.PauseTransferResponse> getPauseTransferMethod() {
    io.grpc.MethodDescriptor<org.peerlink.protocol.v1.PauseTransferRequest, org.peerlink.protocol.v1.PauseTransferResponse> getPauseTransferMethod;
    if ((getPauseTransferMethod = DesktopLocalNodeServiceGrpc.getPauseTransferMethod) == null) {
      synchronized (DesktopLocalNodeServiceGrpc.class) {
        if ((getPauseTransferMethod = DesktopLocalNodeServiceGrpc.getPauseTransferMethod) == null) {
          DesktopLocalNodeServiceGrpc.getPauseTransferMethod = getPauseTransferMethod =
              io.grpc.MethodDescriptor.<org.peerlink.protocol.v1.PauseTransferRequest, org.peerlink.protocol.v1.PauseTransferResponse>newBuilder()
              .setType(io.grpc.MethodDescriptor.MethodType.UNARY)
              .setFullMethodName(generateFullMethodName(SERVICE_NAME, "PauseTransfer"))
              .setSampledToLocalTracing(true)
              .setRequestMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.PauseTransferRequest.getDefaultInstance()))
              .setResponseMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.PauseTransferResponse.getDefaultInstance()))
              .setSchemaDescriptor(new DesktopLocalNodeServiceMethodDescriptorSupplier("PauseTransfer"))
              .build();
        }
      }
    }
    return getPauseTransferMethod;
  }

  private static volatile io.grpc.MethodDescriptor<org.peerlink.protocol.v1.ResumeTransferRequest,
      org.peerlink.protocol.v1.ResumeTransferResponse> getResumeTransferMethod;

  @io.grpc.stub.annotations.RpcMethod(
      fullMethodName = SERVICE_NAME + '/' + "ResumeTransfer",
      requestType = org.peerlink.protocol.v1.ResumeTransferRequest.class,
      responseType = org.peerlink.protocol.v1.ResumeTransferResponse.class,
      methodType = io.grpc.MethodDescriptor.MethodType.UNARY)
  public static io.grpc.MethodDescriptor<org.peerlink.protocol.v1.ResumeTransferRequest,
      org.peerlink.protocol.v1.ResumeTransferResponse> getResumeTransferMethod() {
    io.grpc.MethodDescriptor<org.peerlink.protocol.v1.ResumeTransferRequest, org.peerlink.protocol.v1.ResumeTransferResponse> getResumeTransferMethod;
    if ((getResumeTransferMethod = DesktopLocalNodeServiceGrpc.getResumeTransferMethod) == null) {
      synchronized (DesktopLocalNodeServiceGrpc.class) {
        if ((getResumeTransferMethod = DesktopLocalNodeServiceGrpc.getResumeTransferMethod) == null) {
          DesktopLocalNodeServiceGrpc.getResumeTransferMethod = getResumeTransferMethod =
              io.grpc.MethodDescriptor.<org.peerlink.protocol.v1.ResumeTransferRequest, org.peerlink.protocol.v1.ResumeTransferResponse>newBuilder()
              .setType(io.grpc.MethodDescriptor.MethodType.UNARY)
              .setFullMethodName(generateFullMethodName(SERVICE_NAME, "ResumeTransfer"))
              .setSampledToLocalTracing(true)
              .setRequestMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.ResumeTransferRequest.getDefaultInstance()))
              .setResponseMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.ResumeTransferResponse.getDefaultInstance()))
              .setSchemaDescriptor(new DesktopLocalNodeServiceMethodDescriptorSupplier("ResumeTransfer"))
              .build();
        }
      }
    }
    return getResumeTransferMethod;
  }

  private static volatile io.grpc.MethodDescriptor<org.peerlink.protocol.v1.SetBandwidthLimitRequest,
      org.peerlink.protocol.v1.SetBandwidthLimitResponse> getSetBandwidthLimitMethod;

  @io.grpc.stub.annotations.RpcMethod(
      fullMethodName = SERVICE_NAME + '/' + "SetBandwidthLimit",
      requestType = org.peerlink.protocol.v1.SetBandwidthLimitRequest.class,
      responseType = org.peerlink.protocol.v1.SetBandwidthLimitResponse.class,
      methodType = io.grpc.MethodDescriptor.MethodType.UNARY)
  public static io.grpc.MethodDescriptor<org.peerlink.protocol.v1.SetBandwidthLimitRequest,
      org.peerlink.protocol.v1.SetBandwidthLimitResponse> getSetBandwidthLimitMethod() {
    io.grpc.MethodDescriptor<org.peerlink.protocol.v1.SetBandwidthLimitRequest, org.peerlink.protocol.v1.SetBandwidthLimitResponse> getSetBandwidthLimitMethod;
    if ((getSetBandwidthLimitMethod = DesktopLocalNodeServiceGrpc.getSetBandwidthLimitMethod) == null) {
      synchronized (DesktopLocalNodeServiceGrpc.class) {
        if ((getSetBandwidthLimitMethod = DesktopLocalNodeServiceGrpc.getSetBandwidthLimitMethod) == null) {
          DesktopLocalNodeServiceGrpc.getSetBandwidthLimitMethod = getSetBandwidthLimitMethod =
              io.grpc.MethodDescriptor.<org.peerlink.protocol.v1.SetBandwidthLimitRequest, org.peerlink.protocol.v1.SetBandwidthLimitResponse>newBuilder()
              .setType(io.grpc.MethodDescriptor.MethodType.UNARY)
              .setFullMethodName(generateFullMethodName(SERVICE_NAME, "SetBandwidthLimit"))
              .setSampledToLocalTracing(true)
              .setRequestMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.SetBandwidthLimitRequest.getDefaultInstance()))
              .setResponseMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.SetBandwidthLimitResponse.getDefaultInstance()))
              .setSchemaDescriptor(new DesktopLocalNodeServiceMethodDescriptorSupplier("SetBandwidthLimit"))
              .build();
        }
      }
    }
    return getSetBandwidthLimitMethod;
  }

  private static volatile io.grpc.MethodDescriptor<org.peerlink.protocol.v1.GetTransferRequest,
      org.peerlink.protocol.v1.GetTransferResponse> getGetTransferMethod;

  @io.grpc.stub.annotations.RpcMethod(
      fullMethodName = SERVICE_NAME + '/' + "GetTransfer",
      requestType = org.peerlink.protocol.v1.GetTransferRequest.class,
      responseType = org.peerlink.protocol.v1.GetTransferResponse.class,
      methodType = io.grpc.MethodDescriptor.MethodType.UNARY)
  public static io.grpc.MethodDescriptor<org.peerlink.protocol.v1.GetTransferRequest,
      org.peerlink.protocol.v1.GetTransferResponse> getGetTransferMethod() {
    io.grpc.MethodDescriptor<org.peerlink.protocol.v1.GetTransferRequest, org.peerlink.protocol.v1.GetTransferResponse> getGetTransferMethod;
    if ((getGetTransferMethod = DesktopLocalNodeServiceGrpc.getGetTransferMethod) == null) {
      synchronized (DesktopLocalNodeServiceGrpc.class) {
        if ((getGetTransferMethod = DesktopLocalNodeServiceGrpc.getGetTransferMethod) == null) {
          DesktopLocalNodeServiceGrpc.getGetTransferMethod = getGetTransferMethod =
              io.grpc.MethodDescriptor.<org.peerlink.protocol.v1.GetTransferRequest, org.peerlink.protocol.v1.GetTransferResponse>newBuilder()
              .setType(io.grpc.MethodDescriptor.MethodType.UNARY)
              .setFullMethodName(generateFullMethodName(SERVICE_NAME, "GetTransfer"))
              .setSampledToLocalTracing(true)
              .setRequestMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.GetTransferRequest.getDefaultInstance()))
              .setResponseMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.GetTransferResponse.getDefaultInstance()))
              .setSchemaDescriptor(new DesktopLocalNodeServiceMethodDescriptorSupplier("GetTransfer"))
              .build();
        }
      }
    }
    return getGetTransferMethod;
  }

  private static volatile io.grpc.MethodDescriptor<org.peerlink.protocol.v1.ListTransfersRequest,
      org.peerlink.protocol.v1.ListTransfersResponse> getListTransfersMethod;

  @io.grpc.stub.annotations.RpcMethod(
      fullMethodName = SERVICE_NAME + '/' + "ListTransfers",
      requestType = org.peerlink.protocol.v1.ListTransfersRequest.class,
      responseType = org.peerlink.protocol.v1.ListTransfersResponse.class,
      methodType = io.grpc.MethodDescriptor.MethodType.UNARY)
  public static io.grpc.MethodDescriptor<org.peerlink.protocol.v1.ListTransfersRequest,
      org.peerlink.protocol.v1.ListTransfersResponse> getListTransfersMethod() {
    io.grpc.MethodDescriptor<org.peerlink.protocol.v1.ListTransfersRequest, org.peerlink.protocol.v1.ListTransfersResponse> getListTransfersMethod;
    if ((getListTransfersMethod = DesktopLocalNodeServiceGrpc.getListTransfersMethod) == null) {
      synchronized (DesktopLocalNodeServiceGrpc.class) {
        if ((getListTransfersMethod = DesktopLocalNodeServiceGrpc.getListTransfersMethod) == null) {
          DesktopLocalNodeServiceGrpc.getListTransfersMethod = getListTransfersMethod =
              io.grpc.MethodDescriptor.<org.peerlink.protocol.v1.ListTransfersRequest, org.peerlink.protocol.v1.ListTransfersResponse>newBuilder()
              .setType(io.grpc.MethodDescriptor.MethodType.UNARY)
              .setFullMethodName(generateFullMethodName(SERVICE_NAME, "ListTransfers"))
              .setSampledToLocalTracing(true)
              .setRequestMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.ListTransfersRequest.getDefaultInstance()))
              .setResponseMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.ListTransfersResponse.getDefaultInstance()))
              .setSchemaDescriptor(new DesktopLocalNodeServiceMethodDescriptorSupplier("ListTransfers"))
              .build();
        }
      }
    }
    return getListTransfersMethod;
  }

  private static volatile io.grpc.MethodDescriptor<org.peerlink.protocol.v1.RevealInFolderRequest,
      org.peerlink.protocol.v1.RevealInFolderResponse> getRevealInFolderMethod;

  @io.grpc.stub.annotations.RpcMethod(
      fullMethodName = SERVICE_NAME + '/' + "RevealInFolder",
      requestType = org.peerlink.protocol.v1.RevealInFolderRequest.class,
      responseType = org.peerlink.protocol.v1.RevealInFolderResponse.class,
      methodType = io.grpc.MethodDescriptor.MethodType.UNARY)
  public static io.grpc.MethodDescriptor<org.peerlink.protocol.v1.RevealInFolderRequest,
      org.peerlink.protocol.v1.RevealInFolderResponse> getRevealInFolderMethod() {
    io.grpc.MethodDescriptor<org.peerlink.protocol.v1.RevealInFolderRequest, org.peerlink.protocol.v1.RevealInFolderResponse> getRevealInFolderMethod;
    if ((getRevealInFolderMethod = DesktopLocalNodeServiceGrpc.getRevealInFolderMethod) == null) {
      synchronized (DesktopLocalNodeServiceGrpc.class) {
        if ((getRevealInFolderMethod = DesktopLocalNodeServiceGrpc.getRevealInFolderMethod) == null) {
          DesktopLocalNodeServiceGrpc.getRevealInFolderMethod = getRevealInFolderMethod =
              io.grpc.MethodDescriptor.<org.peerlink.protocol.v1.RevealInFolderRequest, org.peerlink.protocol.v1.RevealInFolderResponse>newBuilder()
              .setType(io.grpc.MethodDescriptor.MethodType.UNARY)
              .setFullMethodName(generateFullMethodName(SERVICE_NAME, "RevealInFolder"))
              .setSampledToLocalTracing(true)
              .setRequestMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.RevealInFolderRequest.getDefaultInstance()))
              .setResponseMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  org.peerlink.protocol.v1.RevealInFolderResponse.getDefaultInstance()))
              .setSchemaDescriptor(new DesktopLocalNodeServiceMethodDescriptorSupplier("RevealInFolder"))
              .build();
        }
      }
    }
    return getRevealInFolderMethod;
  }

  /**
   * Creates a new async stub that supports all call types for the service
   */
  public static DesktopLocalNodeServiceStub newStub(io.grpc.Channel channel) {
    io.grpc.stub.AbstractStub.StubFactory<DesktopLocalNodeServiceStub> factory =
      new io.grpc.stub.AbstractStub.StubFactory<DesktopLocalNodeServiceStub>() {
        @java.lang.Override
        public DesktopLocalNodeServiceStub newStub(io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
          return new DesktopLocalNodeServiceStub(channel, callOptions);
        }
      };
    return DesktopLocalNodeServiceStub.newStub(factory, channel);
  }

  /**
   * Creates a new blocking-style stub that supports unary and streaming output calls on the service
   */
  public static DesktopLocalNodeServiceBlockingStub newBlockingStub(
      io.grpc.Channel channel) {
    io.grpc.stub.AbstractStub.StubFactory<DesktopLocalNodeServiceBlockingStub> factory =
      new io.grpc.stub.AbstractStub.StubFactory<DesktopLocalNodeServiceBlockingStub>() {
        @java.lang.Override
        public DesktopLocalNodeServiceBlockingStub newStub(io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
          return new DesktopLocalNodeServiceBlockingStub(channel, callOptions);
        }
      };
    return DesktopLocalNodeServiceBlockingStub.newStub(factory, channel);
  }

  /**
   * Creates a new ListenableFuture-style stub that supports unary calls on the service
   */
  public static DesktopLocalNodeServiceFutureStub newFutureStub(
      io.grpc.Channel channel) {
    io.grpc.stub.AbstractStub.StubFactory<DesktopLocalNodeServiceFutureStub> factory =
      new io.grpc.stub.AbstractStub.StubFactory<DesktopLocalNodeServiceFutureStub>() {
        @java.lang.Override
        public DesktopLocalNodeServiceFutureStub newStub(io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
          return new DesktopLocalNodeServiceFutureStub(channel, callOptions);
        }
      };
    return DesktopLocalNodeServiceFutureStub.newStub(factory, channel);
  }

  /**
   */
  public interface AsyncService {

    /**
     */
    default void authenticate(org.peerlink.protocol.v1.AuthenticateIpcRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.AuthenticateIpcResponse> responseObserver) {
      io.grpc.stub.ServerCalls.asyncUnimplementedUnaryCall(getAuthenticateMethod(), responseObserver);
    }

    /**
     */
    default void getStatus(org.peerlink.protocol.v1.GetNodeStatusRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.GetNodeStatusResponse> responseObserver) {
      io.grpc.stub.ServerCalls.asyncUnimplementedUnaryCall(getGetStatusMethod(), responseObserver);
    }

    /**
     */
    default void subscribeEvents(org.peerlink.protocol.v1.NodeEventSubscriptionRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.NodeEvent> responseObserver) {
      io.grpc.stub.ServerCalls.asyncUnimplementedUnaryCall(getSubscribeEventsMethod(), responseObserver);
    }

    /**
     */
    default void restart(org.peerlink.protocol.v1.RestartNodeRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.RestartNodeResponse> responseObserver) {
      io.grpc.stub.ServerCalls.asyncUnimplementedUnaryCall(getRestartMethod(), responseObserver);
    }

    /**
     */
    default void stop(org.peerlink.protocol.v1.StopNodeRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.StopNodeResponse> responseObserver) {
      io.grpc.stub.ServerCalls.asyncUnimplementedUnaryCall(getStopMethod(), responseObserver);
    }

    /**
     */
    default void initiateSend(org.peerlink.protocol.v1.InitiateSendRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.InitiateSendResponse> responseObserver) {
      io.grpc.stub.ServerCalls.asyncUnimplementedUnaryCall(getInitiateSendMethod(), responseObserver);
    }

    /**
     */
    default void cancelTransfer(org.peerlink.protocol.v1.CancelTransferRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.CancelTransferResponse> responseObserver) {
      io.grpc.stub.ServerCalls.asyncUnimplementedUnaryCall(getCancelTransferMethod(), responseObserver);
    }

    /**
     */
    default void pauseTransfer(org.peerlink.protocol.v1.PauseTransferRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.PauseTransferResponse> responseObserver) {
      io.grpc.stub.ServerCalls.asyncUnimplementedUnaryCall(getPauseTransferMethod(), responseObserver);
    }

    /**
     */
    default void resumeTransfer(org.peerlink.protocol.v1.ResumeTransferRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.ResumeTransferResponse> responseObserver) {
      io.grpc.stub.ServerCalls.asyncUnimplementedUnaryCall(getResumeTransferMethod(), responseObserver);
    }

    /**
     */
    default void setBandwidthLimit(org.peerlink.protocol.v1.SetBandwidthLimitRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.SetBandwidthLimitResponse> responseObserver) {
      io.grpc.stub.ServerCalls.asyncUnimplementedUnaryCall(getSetBandwidthLimitMethod(), responseObserver);
    }

    /**
     */
    default void getTransfer(org.peerlink.protocol.v1.GetTransferRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.GetTransferResponse> responseObserver) {
      io.grpc.stub.ServerCalls.asyncUnimplementedUnaryCall(getGetTransferMethod(), responseObserver);
    }

    /**
     */
    default void listTransfers(org.peerlink.protocol.v1.ListTransfersRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.ListTransfersResponse> responseObserver) {
      io.grpc.stub.ServerCalls.asyncUnimplementedUnaryCall(getListTransfersMethod(), responseObserver);
    }

    /**
     */
    default void revealInFolder(org.peerlink.protocol.v1.RevealInFolderRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.RevealInFolderResponse> responseObserver) {
      io.grpc.stub.ServerCalls.asyncUnimplementedUnaryCall(getRevealInFolderMethod(), responseObserver);
    }
  }

  /**
   * Base class for the server implementation of the service DesktopLocalNodeService.
   */
  public static abstract class DesktopLocalNodeServiceImplBase
      implements io.grpc.BindableService, AsyncService {

    @java.lang.Override public final io.grpc.ServerServiceDefinition bindService() {
      return DesktopLocalNodeServiceGrpc.bindService(this);
    }
  }

  /**
   * A stub to allow clients to do asynchronous rpc calls to service DesktopLocalNodeService.
   */
  public static final class DesktopLocalNodeServiceStub
      extends io.grpc.stub.AbstractAsyncStub<DesktopLocalNodeServiceStub> {
    private DesktopLocalNodeServiceStub(
        io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
      super(channel, callOptions);
    }

    @java.lang.Override
    protected DesktopLocalNodeServiceStub build(
        io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
      return new DesktopLocalNodeServiceStub(channel, callOptions);
    }

    /**
     */
    public void authenticate(org.peerlink.protocol.v1.AuthenticateIpcRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.AuthenticateIpcResponse> responseObserver) {
      io.grpc.stub.ClientCalls.asyncUnaryCall(
          getChannel().newCall(getAuthenticateMethod(), getCallOptions()), request, responseObserver);
    }

    /**
     */
    public void getStatus(org.peerlink.protocol.v1.GetNodeStatusRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.GetNodeStatusResponse> responseObserver) {
      io.grpc.stub.ClientCalls.asyncUnaryCall(
          getChannel().newCall(getGetStatusMethod(), getCallOptions()), request, responseObserver);
    }

    /**
     */
    public void subscribeEvents(org.peerlink.protocol.v1.NodeEventSubscriptionRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.NodeEvent> responseObserver) {
      io.grpc.stub.ClientCalls.asyncServerStreamingCall(
          getChannel().newCall(getSubscribeEventsMethod(), getCallOptions()), request, responseObserver);
    }

    /**
     */
    public void restart(org.peerlink.protocol.v1.RestartNodeRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.RestartNodeResponse> responseObserver) {
      io.grpc.stub.ClientCalls.asyncUnaryCall(
          getChannel().newCall(getRestartMethod(), getCallOptions()), request, responseObserver);
    }

    /**
     */
    public void stop(org.peerlink.protocol.v1.StopNodeRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.StopNodeResponse> responseObserver) {
      io.grpc.stub.ClientCalls.asyncUnaryCall(
          getChannel().newCall(getStopMethod(), getCallOptions()), request, responseObserver);
    }

    /**
     */
    public void initiateSend(org.peerlink.protocol.v1.InitiateSendRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.InitiateSendResponse> responseObserver) {
      io.grpc.stub.ClientCalls.asyncUnaryCall(
          getChannel().newCall(getInitiateSendMethod(), getCallOptions()), request, responseObserver);
    }

    /**
     */
    public void cancelTransfer(org.peerlink.protocol.v1.CancelTransferRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.CancelTransferResponse> responseObserver) {
      io.grpc.stub.ClientCalls.asyncUnaryCall(
          getChannel().newCall(getCancelTransferMethod(), getCallOptions()), request, responseObserver);
    }

    /**
     */
    public void pauseTransfer(org.peerlink.protocol.v1.PauseTransferRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.PauseTransferResponse> responseObserver) {
      io.grpc.stub.ClientCalls.asyncUnaryCall(
          getChannel().newCall(getPauseTransferMethod(), getCallOptions()), request, responseObserver);
    }

    /**
     */
    public void resumeTransfer(org.peerlink.protocol.v1.ResumeTransferRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.ResumeTransferResponse> responseObserver) {
      io.grpc.stub.ClientCalls.asyncUnaryCall(
          getChannel().newCall(getResumeTransferMethod(), getCallOptions()), request, responseObserver);
    }

    /**
     */
    public void setBandwidthLimit(org.peerlink.protocol.v1.SetBandwidthLimitRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.SetBandwidthLimitResponse> responseObserver) {
      io.grpc.stub.ClientCalls.asyncUnaryCall(
          getChannel().newCall(getSetBandwidthLimitMethod(), getCallOptions()), request, responseObserver);
    }

    /**
     */
    public void getTransfer(org.peerlink.protocol.v1.GetTransferRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.GetTransferResponse> responseObserver) {
      io.grpc.stub.ClientCalls.asyncUnaryCall(
          getChannel().newCall(getGetTransferMethod(), getCallOptions()), request, responseObserver);
    }

    /**
     */
    public void listTransfers(org.peerlink.protocol.v1.ListTransfersRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.ListTransfersResponse> responseObserver) {
      io.grpc.stub.ClientCalls.asyncUnaryCall(
          getChannel().newCall(getListTransfersMethod(), getCallOptions()), request, responseObserver);
    }

    /**
     */
    public void revealInFolder(org.peerlink.protocol.v1.RevealInFolderRequest request,
        io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.RevealInFolderResponse> responseObserver) {
      io.grpc.stub.ClientCalls.asyncUnaryCall(
          getChannel().newCall(getRevealInFolderMethod(), getCallOptions()), request, responseObserver);
    }
  }

  /**
   * A stub to allow clients to do synchronous rpc calls to service DesktopLocalNodeService.
   */
  public static final class DesktopLocalNodeServiceBlockingStub
      extends io.grpc.stub.AbstractBlockingStub<DesktopLocalNodeServiceBlockingStub> {
    private DesktopLocalNodeServiceBlockingStub(
        io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
      super(channel, callOptions);
    }

    @java.lang.Override
    protected DesktopLocalNodeServiceBlockingStub build(
        io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
      return new DesktopLocalNodeServiceBlockingStub(channel, callOptions);
    }

    /**
     */
    public org.peerlink.protocol.v1.AuthenticateIpcResponse authenticate(org.peerlink.protocol.v1.AuthenticateIpcRequest request) {
      return io.grpc.stub.ClientCalls.blockingUnaryCall(
          getChannel(), getAuthenticateMethod(), getCallOptions(), request);
    }

    /**
     */
    public org.peerlink.protocol.v1.GetNodeStatusResponse getStatus(org.peerlink.protocol.v1.GetNodeStatusRequest request) {
      return io.grpc.stub.ClientCalls.blockingUnaryCall(
          getChannel(), getGetStatusMethod(), getCallOptions(), request);
    }

    /**
     */
    public java.util.Iterator<org.peerlink.protocol.v1.NodeEvent> subscribeEvents(
        org.peerlink.protocol.v1.NodeEventSubscriptionRequest request) {
      return io.grpc.stub.ClientCalls.blockingServerStreamingCall(
          getChannel(), getSubscribeEventsMethod(), getCallOptions(), request);
    }

    /**
     */
    public org.peerlink.protocol.v1.RestartNodeResponse restart(org.peerlink.protocol.v1.RestartNodeRequest request) {
      return io.grpc.stub.ClientCalls.blockingUnaryCall(
          getChannel(), getRestartMethod(), getCallOptions(), request);
    }

    /**
     */
    public org.peerlink.protocol.v1.StopNodeResponse stop(org.peerlink.protocol.v1.StopNodeRequest request) {
      return io.grpc.stub.ClientCalls.blockingUnaryCall(
          getChannel(), getStopMethod(), getCallOptions(), request);
    }

    /**
     */
    public org.peerlink.protocol.v1.InitiateSendResponse initiateSend(org.peerlink.protocol.v1.InitiateSendRequest request) {
      return io.grpc.stub.ClientCalls.blockingUnaryCall(
          getChannel(), getInitiateSendMethod(), getCallOptions(), request);
    }

    /**
     */
    public org.peerlink.protocol.v1.CancelTransferResponse cancelTransfer(org.peerlink.protocol.v1.CancelTransferRequest request) {
      return io.grpc.stub.ClientCalls.blockingUnaryCall(
          getChannel(), getCancelTransferMethod(), getCallOptions(), request);
    }

    /**
     */
    public org.peerlink.protocol.v1.PauseTransferResponse pauseTransfer(org.peerlink.protocol.v1.PauseTransferRequest request) {
      return io.grpc.stub.ClientCalls.blockingUnaryCall(
          getChannel(), getPauseTransferMethod(), getCallOptions(), request);
    }

    /**
     */
    public org.peerlink.protocol.v1.ResumeTransferResponse resumeTransfer(org.peerlink.protocol.v1.ResumeTransferRequest request) {
      return io.grpc.stub.ClientCalls.blockingUnaryCall(
          getChannel(), getResumeTransferMethod(), getCallOptions(), request);
    }

    /**
     */
    public org.peerlink.protocol.v1.SetBandwidthLimitResponse setBandwidthLimit(org.peerlink.protocol.v1.SetBandwidthLimitRequest request) {
      return io.grpc.stub.ClientCalls.blockingUnaryCall(
          getChannel(), getSetBandwidthLimitMethod(), getCallOptions(), request);
    }

    /**
     */
    public org.peerlink.protocol.v1.GetTransferResponse getTransfer(org.peerlink.protocol.v1.GetTransferRequest request) {
      return io.grpc.stub.ClientCalls.blockingUnaryCall(
          getChannel(), getGetTransferMethod(), getCallOptions(), request);
    }

    /**
     */
    public org.peerlink.protocol.v1.ListTransfersResponse listTransfers(org.peerlink.protocol.v1.ListTransfersRequest request) {
      return io.grpc.stub.ClientCalls.blockingUnaryCall(
          getChannel(), getListTransfersMethod(), getCallOptions(), request);
    }

    /**
     */
    public org.peerlink.protocol.v1.RevealInFolderResponse revealInFolder(org.peerlink.protocol.v1.RevealInFolderRequest request) {
      return io.grpc.stub.ClientCalls.blockingUnaryCall(
          getChannel(), getRevealInFolderMethod(), getCallOptions(), request);
    }
  }

  /**
   * A stub to allow clients to do ListenableFuture-style rpc calls to service DesktopLocalNodeService.
   */
  public static final class DesktopLocalNodeServiceFutureStub
      extends io.grpc.stub.AbstractFutureStub<DesktopLocalNodeServiceFutureStub> {
    private DesktopLocalNodeServiceFutureStub(
        io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
      super(channel, callOptions);
    }

    @java.lang.Override
    protected DesktopLocalNodeServiceFutureStub build(
        io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
      return new DesktopLocalNodeServiceFutureStub(channel, callOptions);
    }

    /**
     */
    public com.google.common.util.concurrent.ListenableFuture<org.peerlink.protocol.v1.AuthenticateIpcResponse> authenticate(
        org.peerlink.protocol.v1.AuthenticateIpcRequest request) {
      return io.grpc.stub.ClientCalls.futureUnaryCall(
          getChannel().newCall(getAuthenticateMethod(), getCallOptions()), request);
    }

    /**
     */
    public com.google.common.util.concurrent.ListenableFuture<org.peerlink.protocol.v1.GetNodeStatusResponse> getStatus(
        org.peerlink.protocol.v1.GetNodeStatusRequest request) {
      return io.grpc.stub.ClientCalls.futureUnaryCall(
          getChannel().newCall(getGetStatusMethod(), getCallOptions()), request);
    }

    /**
     */
    public com.google.common.util.concurrent.ListenableFuture<org.peerlink.protocol.v1.RestartNodeResponse> restart(
        org.peerlink.protocol.v1.RestartNodeRequest request) {
      return io.grpc.stub.ClientCalls.futureUnaryCall(
          getChannel().newCall(getRestartMethod(), getCallOptions()), request);
    }

    /**
     */
    public com.google.common.util.concurrent.ListenableFuture<org.peerlink.protocol.v1.StopNodeResponse> stop(
        org.peerlink.protocol.v1.StopNodeRequest request) {
      return io.grpc.stub.ClientCalls.futureUnaryCall(
          getChannel().newCall(getStopMethod(), getCallOptions()), request);
    }

    /**
     */
    public com.google.common.util.concurrent.ListenableFuture<org.peerlink.protocol.v1.InitiateSendResponse> initiateSend(
        org.peerlink.protocol.v1.InitiateSendRequest request) {
      return io.grpc.stub.ClientCalls.futureUnaryCall(
          getChannel().newCall(getInitiateSendMethod(), getCallOptions()), request);
    }

    /**
     */
    public com.google.common.util.concurrent.ListenableFuture<org.peerlink.protocol.v1.CancelTransferResponse> cancelTransfer(
        org.peerlink.protocol.v1.CancelTransferRequest request) {
      return io.grpc.stub.ClientCalls.futureUnaryCall(
          getChannel().newCall(getCancelTransferMethod(), getCallOptions()), request);
    }

    /**
     */
    public com.google.common.util.concurrent.ListenableFuture<org.peerlink.protocol.v1.PauseTransferResponse> pauseTransfer(
        org.peerlink.protocol.v1.PauseTransferRequest request) {
      return io.grpc.stub.ClientCalls.futureUnaryCall(
          getChannel().newCall(getPauseTransferMethod(), getCallOptions()), request);
    }

    /**
     */
    public com.google.common.util.concurrent.ListenableFuture<org.peerlink.protocol.v1.ResumeTransferResponse> resumeTransfer(
        org.peerlink.protocol.v1.ResumeTransferRequest request) {
      return io.grpc.stub.ClientCalls.futureUnaryCall(
          getChannel().newCall(getResumeTransferMethod(), getCallOptions()), request);
    }

    /**
     */
    public com.google.common.util.concurrent.ListenableFuture<org.peerlink.protocol.v1.SetBandwidthLimitResponse> setBandwidthLimit(
        org.peerlink.protocol.v1.SetBandwidthLimitRequest request) {
      return io.grpc.stub.ClientCalls.futureUnaryCall(
          getChannel().newCall(getSetBandwidthLimitMethod(), getCallOptions()), request);
    }

    /**
     */
    public com.google.common.util.concurrent.ListenableFuture<org.peerlink.protocol.v1.GetTransferResponse> getTransfer(
        org.peerlink.protocol.v1.GetTransferRequest request) {
      return io.grpc.stub.ClientCalls.futureUnaryCall(
          getChannel().newCall(getGetTransferMethod(), getCallOptions()), request);
    }

    /**
     */
    public com.google.common.util.concurrent.ListenableFuture<org.peerlink.protocol.v1.ListTransfersResponse> listTransfers(
        org.peerlink.protocol.v1.ListTransfersRequest request) {
      return io.grpc.stub.ClientCalls.futureUnaryCall(
          getChannel().newCall(getListTransfersMethod(), getCallOptions()), request);
    }

    /**
     */
    public com.google.common.util.concurrent.ListenableFuture<org.peerlink.protocol.v1.RevealInFolderResponse> revealInFolder(
        org.peerlink.protocol.v1.RevealInFolderRequest request) {
      return io.grpc.stub.ClientCalls.futureUnaryCall(
          getChannel().newCall(getRevealInFolderMethod(), getCallOptions()), request);
    }
  }

  private static final int METHODID_AUTHENTICATE = 0;
  private static final int METHODID_GET_STATUS = 1;
  private static final int METHODID_SUBSCRIBE_EVENTS = 2;
  private static final int METHODID_RESTART = 3;
  private static final int METHODID_STOP = 4;
  private static final int METHODID_INITIATE_SEND = 5;
  private static final int METHODID_CANCEL_TRANSFER = 6;
  private static final int METHODID_PAUSE_TRANSFER = 7;
  private static final int METHODID_RESUME_TRANSFER = 8;
  private static final int METHODID_SET_BANDWIDTH_LIMIT = 9;
  private static final int METHODID_GET_TRANSFER = 10;
  private static final int METHODID_LIST_TRANSFERS = 11;
  private static final int METHODID_REVEAL_IN_FOLDER = 12;

  private static final class MethodHandlers<Req, Resp> implements
      io.grpc.stub.ServerCalls.UnaryMethod<Req, Resp>,
      io.grpc.stub.ServerCalls.ServerStreamingMethod<Req, Resp>,
      io.grpc.stub.ServerCalls.ClientStreamingMethod<Req, Resp>,
      io.grpc.stub.ServerCalls.BidiStreamingMethod<Req, Resp> {
    private final AsyncService serviceImpl;
    private final int methodId;

    MethodHandlers(AsyncService serviceImpl, int methodId) {
      this.serviceImpl = serviceImpl;
      this.methodId = methodId;
    }

    @java.lang.Override
    @java.lang.SuppressWarnings("unchecked")
    public void invoke(Req request, io.grpc.stub.StreamObserver<Resp> responseObserver) {
      switch (methodId) {
        case METHODID_AUTHENTICATE:
          serviceImpl.authenticate((org.peerlink.protocol.v1.AuthenticateIpcRequest) request,
              (io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.AuthenticateIpcResponse>) responseObserver);
          break;
        case METHODID_GET_STATUS:
          serviceImpl.getStatus((org.peerlink.protocol.v1.GetNodeStatusRequest) request,
              (io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.GetNodeStatusResponse>) responseObserver);
          break;
        case METHODID_SUBSCRIBE_EVENTS:
          serviceImpl.subscribeEvents((org.peerlink.protocol.v1.NodeEventSubscriptionRequest) request,
              (io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.NodeEvent>) responseObserver);
          break;
        case METHODID_RESTART:
          serviceImpl.restart((org.peerlink.protocol.v1.RestartNodeRequest) request,
              (io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.RestartNodeResponse>) responseObserver);
          break;
        case METHODID_STOP:
          serviceImpl.stop((org.peerlink.protocol.v1.StopNodeRequest) request,
              (io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.StopNodeResponse>) responseObserver);
          break;
        case METHODID_INITIATE_SEND:
          serviceImpl.initiateSend((org.peerlink.protocol.v1.InitiateSendRequest) request,
              (io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.InitiateSendResponse>) responseObserver);
          break;
        case METHODID_CANCEL_TRANSFER:
          serviceImpl.cancelTransfer((org.peerlink.protocol.v1.CancelTransferRequest) request,
              (io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.CancelTransferResponse>) responseObserver);
          break;
        case METHODID_PAUSE_TRANSFER:
          serviceImpl.pauseTransfer((org.peerlink.protocol.v1.PauseTransferRequest) request,
              (io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.PauseTransferResponse>) responseObserver);
          break;
        case METHODID_RESUME_TRANSFER:
          serviceImpl.resumeTransfer((org.peerlink.protocol.v1.ResumeTransferRequest) request,
              (io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.ResumeTransferResponse>) responseObserver);
          break;
        case METHODID_SET_BANDWIDTH_LIMIT:
          serviceImpl.setBandwidthLimit((org.peerlink.protocol.v1.SetBandwidthLimitRequest) request,
              (io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.SetBandwidthLimitResponse>) responseObserver);
          break;
        case METHODID_GET_TRANSFER:
          serviceImpl.getTransfer((org.peerlink.protocol.v1.GetTransferRequest) request,
              (io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.GetTransferResponse>) responseObserver);
          break;
        case METHODID_LIST_TRANSFERS:
          serviceImpl.listTransfers((org.peerlink.protocol.v1.ListTransfersRequest) request,
              (io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.ListTransfersResponse>) responseObserver);
          break;
        case METHODID_REVEAL_IN_FOLDER:
          serviceImpl.revealInFolder((org.peerlink.protocol.v1.RevealInFolderRequest) request,
              (io.grpc.stub.StreamObserver<org.peerlink.protocol.v1.RevealInFolderResponse>) responseObserver);
          break;
        default:
          throw new AssertionError();
      }
    }

    @java.lang.Override
    @java.lang.SuppressWarnings("unchecked")
    public io.grpc.stub.StreamObserver<Req> invoke(
        io.grpc.stub.StreamObserver<Resp> responseObserver) {
      switch (methodId) {
        default:
          throw new AssertionError();
      }
    }
  }

  public static final io.grpc.ServerServiceDefinition bindService(AsyncService service) {
    return io.grpc.ServerServiceDefinition.builder(getServiceDescriptor())
        .addMethod(
          getAuthenticateMethod(),
          io.grpc.stub.ServerCalls.asyncUnaryCall(
            new MethodHandlers<
              org.peerlink.protocol.v1.AuthenticateIpcRequest,
              org.peerlink.protocol.v1.AuthenticateIpcResponse>(
                service, METHODID_AUTHENTICATE)))
        .addMethod(
          getGetStatusMethod(),
          io.grpc.stub.ServerCalls.asyncUnaryCall(
            new MethodHandlers<
              org.peerlink.protocol.v1.GetNodeStatusRequest,
              org.peerlink.protocol.v1.GetNodeStatusResponse>(
                service, METHODID_GET_STATUS)))
        .addMethod(
          getSubscribeEventsMethod(),
          io.grpc.stub.ServerCalls.asyncServerStreamingCall(
            new MethodHandlers<
              org.peerlink.protocol.v1.NodeEventSubscriptionRequest,
              org.peerlink.protocol.v1.NodeEvent>(
                service, METHODID_SUBSCRIBE_EVENTS)))
        .addMethod(
          getRestartMethod(),
          io.grpc.stub.ServerCalls.asyncUnaryCall(
            new MethodHandlers<
              org.peerlink.protocol.v1.RestartNodeRequest,
              org.peerlink.protocol.v1.RestartNodeResponse>(
                service, METHODID_RESTART)))
        .addMethod(
          getStopMethod(),
          io.grpc.stub.ServerCalls.asyncUnaryCall(
            new MethodHandlers<
              org.peerlink.protocol.v1.StopNodeRequest,
              org.peerlink.protocol.v1.StopNodeResponse>(
                service, METHODID_STOP)))
        .addMethod(
          getInitiateSendMethod(),
          io.grpc.stub.ServerCalls.asyncUnaryCall(
            new MethodHandlers<
              org.peerlink.protocol.v1.InitiateSendRequest,
              org.peerlink.protocol.v1.InitiateSendResponse>(
                service, METHODID_INITIATE_SEND)))
        .addMethod(
          getCancelTransferMethod(),
          io.grpc.stub.ServerCalls.asyncUnaryCall(
            new MethodHandlers<
              org.peerlink.protocol.v1.CancelTransferRequest,
              org.peerlink.protocol.v1.CancelTransferResponse>(
                service, METHODID_CANCEL_TRANSFER)))
        .addMethod(
          getPauseTransferMethod(),
          io.grpc.stub.ServerCalls.asyncUnaryCall(
            new MethodHandlers<
              org.peerlink.protocol.v1.PauseTransferRequest,
              org.peerlink.protocol.v1.PauseTransferResponse>(
                service, METHODID_PAUSE_TRANSFER)))
        .addMethod(
          getResumeTransferMethod(),
          io.grpc.stub.ServerCalls.asyncUnaryCall(
            new MethodHandlers<
              org.peerlink.protocol.v1.ResumeTransferRequest,
              org.peerlink.protocol.v1.ResumeTransferResponse>(
                service, METHODID_RESUME_TRANSFER)))
        .addMethod(
          getSetBandwidthLimitMethod(),
          io.grpc.stub.ServerCalls.asyncUnaryCall(
            new MethodHandlers<
              org.peerlink.protocol.v1.SetBandwidthLimitRequest,
              org.peerlink.protocol.v1.SetBandwidthLimitResponse>(
                service, METHODID_SET_BANDWIDTH_LIMIT)))
        .addMethod(
          getGetTransferMethod(),
          io.grpc.stub.ServerCalls.asyncUnaryCall(
            new MethodHandlers<
              org.peerlink.protocol.v1.GetTransferRequest,
              org.peerlink.protocol.v1.GetTransferResponse>(
                service, METHODID_GET_TRANSFER)))
        .addMethod(
          getListTransfersMethod(),
          io.grpc.stub.ServerCalls.asyncUnaryCall(
            new MethodHandlers<
              org.peerlink.protocol.v1.ListTransfersRequest,
              org.peerlink.protocol.v1.ListTransfersResponse>(
                service, METHODID_LIST_TRANSFERS)))
        .addMethod(
          getRevealInFolderMethod(),
          io.grpc.stub.ServerCalls.asyncUnaryCall(
            new MethodHandlers<
              org.peerlink.protocol.v1.RevealInFolderRequest,
              org.peerlink.protocol.v1.RevealInFolderResponse>(
                service, METHODID_REVEAL_IN_FOLDER)))
        .build();
  }

  private static abstract class DesktopLocalNodeServiceBaseDescriptorSupplier
      implements io.grpc.protobuf.ProtoFileDescriptorSupplier, io.grpc.protobuf.ProtoServiceDescriptorSupplier {
    DesktopLocalNodeServiceBaseDescriptorSupplier() {}

    @java.lang.Override
    public com.google.protobuf.Descriptors.FileDescriptor getFileDescriptor() {
      return org.peerlink.protocol.v1.Ipc.getDescriptor();
    }

    @java.lang.Override
    public com.google.protobuf.Descriptors.ServiceDescriptor getServiceDescriptor() {
      return getFileDescriptor().findServiceByName("DesktopLocalNodeService");
    }
  }

  private static final class DesktopLocalNodeServiceFileDescriptorSupplier
      extends DesktopLocalNodeServiceBaseDescriptorSupplier {
    DesktopLocalNodeServiceFileDescriptorSupplier() {}
  }

  private static final class DesktopLocalNodeServiceMethodDescriptorSupplier
      extends DesktopLocalNodeServiceBaseDescriptorSupplier
      implements io.grpc.protobuf.ProtoMethodDescriptorSupplier {
    private final java.lang.String methodName;

    DesktopLocalNodeServiceMethodDescriptorSupplier(java.lang.String methodName) {
      this.methodName = methodName;
    }

    @java.lang.Override
    public com.google.protobuf.Descriptors.MethodDescriptor getMethodDescriptor() {
      return getServiceDescriptor().findMethodByName(methodName);
    }
  }

  private static volatile io.grpc.ServiceDescriptor serviceDescriptor;

  public static io.grpc.ServiceDescriptor getServiceDescriptor() {
    io.grpc.ServiceDescriptor result = serviceDescriptor;
    if (result == null) {
      synchronized (DesktopLocalNodeServiceGrpc.class) {
        result = serviceDescriptor;
        if (result == null) {
          serviceDescriptor = result = io.grpc.ServiceDescriptor.newBuilder(SERVICE_NAME)
              .setSchemaDescriptor(new DesktopLocalNodeServiceFileDescriptorSupplier())
              .addMethod(getAuthenticateMethod())
              .addMethod(getGetStatusMethod())
              .addMethod(getSubscribeEventsMethod())
              .addMethod(getRestartMethod())
              .addMethod(getStopMethod())
              .addMethod(getInitiateSendMethod())
              .addMethod(getCancelTransferMethod())
              .addMethod(getPauseTransferMethod())
              .addMethod(getResumeTransferMethod())
              .addMethod(getSetBandwidthLimitMethod())
              .addMethod(getGetTransferMethod())
              .addMethod(getListTransfersMethod())
              .addMethod(getRevealInFolderMethod())
              .build();
        }
      }
    }
    return result;
  }
}
