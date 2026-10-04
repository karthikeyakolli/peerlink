// This is a generated file - do not edit.
//
// Generated from peerlink/v1/ipc.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'ipc.pb.dart' as $0;

export 'ipc.pb.dart';

@$pb.GrpcServiceName('peerlink.v1.DesktopLocalNodeService')
class DesktopLocalNodeServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  DesktopLocalNodeServiceClient(super.channel,
      {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.AuthenticateIpcResponse> authenticate(
    $0.AuthenticateIpcRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$authenticate, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetNodeStatusResponse> getStatus(
    $0.GetNodeStatusRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getStatus, request, options: options);
  }

  $grpc.ResponseStream<$0.NodeEvent> subscribeEvents(
    $0.NodeEventSubscriptionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$subscribeEvents, $async.Stream.fromIterable([request]),
        options: options);
  }

  $grpc.ResponseFuture<$0.RestartNodeResponse> restart(
    $0.RestartNodeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$restart, request, options: options);
  }

  $grpc.ResponseFuture<$0.StopNodeResponse> stop(
    $0.StopNodeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$stop, request, options: options);
  }

  $grpc.ResponseFuture<$0.InitiateSendResponse> initiateSend(
    $0.InitiateSendRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$initiateSend, request, options: options);
  }

  $grpc.ResponseFuture<$0.CancelTransferResponse> cancelTransfer(
    $0.CancelTransferRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$cancelTransfer, request, options: options);
  }

  $grpc.ResponseFuture<$0.PauseTransferResponse> pauseTransfer(
    $0.PauseTransferRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$pauseTransfer, request, options: options);
  }

  $grpc.ResponseFuture<$0.ResumeTransferResponse> resumeTransfer(
    $0.ResumeTransferRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$resumeTransfer, request, options: options);
  }

  $grpc.ResponseFuture<$0.SetBandwidthLimitResponse> setBandwidthLimit(
    $0.SetBandwidthLimitRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$setBandwidthLimit, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetTransferResponse> getTransfer(
    $0.GetTransferRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getTransfer, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListTransfersResponse> listTransfers(
    $0.ListTransfersRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listTransfers, request, options: options);
  }

  $grpc.ResponseFuture<$0.RevealInFolderResponse> revealInFolder(
    $0.RevealInFolderRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$revealInFolder, request, options: options);
  }

  // method descriptors

  static final _$authenticate =
      $grpc.ClientMethod<$0.AuthenticateIpcRequest, $0.AuthenticateIpcResponse>(
          '/peerlink.v1.DesktopLocalNodeService/Authenticate',
          ($0.AuthenticateIpcRequest value) => value.writeToBuffer(),
          $0.AuthenticateIpcResponse.fromBuffer);
  static final _$getStatus =
      $grpc.ClientMethod<$0.GetNodeStatusRequest, $0.GetNodeStatusResponse>(
          '/peerlink.v1.DesktopLocalNodeService/GetStatus',
          ($0.GetNodeStatusRequest value) => value.writeToBuffer(),
          $0.GetNodeStatusResponse.fromBuffer);
  static final _$subscribeEvents =
      $grpc.ClientMethod<$0.NodeEventSubscriptionRequest, $0.NodeEvent>(
          '/peerlink.v1.DesktopLocalNodeService/SubscribeEvents',
          ($0.NodeEventSubscriptionRequest value) => value.writeToBuffer(),
          $0.NodeEvent.fromBuffer);
  static final _$restart =
      $grpc.ClientMethod<$0.RestartNodeRequest, $0.RestartNodeResponse>(
          '/peerlink.v1.DesktopLocalNodeService/Restart',
          ($0.RestartNodeRequest value) => value.writeToBuffer(),
          $0.RestartNodeResponse.fromBuffer);
  static final _$stop =
      $grpc.ClientMethod<$0.StopNodeRequest, $0.StopNodeResponse>(
          '/peerlink.v1.DesktopLocalNodeService/Stop',
          ($0.StopNodeRequest value) => value.writeToBuffer(),
          $0.StopNodeResponse.fromBuffer);
  static final _$initiateSend =
      $grpc.ClientMethod<$0.InitiateSendRequest, $0.InitiateSendResponse>(
          '/peerlink.v1.DesktopLocalNodeService/InitiateSend',
          ($0.InitiateSendRequest value) => value.writeToBuffer(),
          $0.InitiateSendResponse.fromBuffer);
  static final _$cancelTransfer =
      $grpc.ClientMethod<$0.CancelTransferRequest, $0.CancelTransferResponse>(
          '/peerlink.v1.DesktopLocalNodeService/CancelTransfer',
          ($0.CancelTransferRequest value) => value.writeToBuffer(),
          $0.CancelTransferResponse.fromBuffer);
  static final _$pauseTransfer =
      $grpc.ClientMethod<$0.PauseTransferRequest, $0.PauseTransferResponse>(
          '/peerlink.v1.DesktopLocalNodeService/PauseTransfer',
          ($0.PauseTransferRequest value) => value.writeToBuffer(),
          $0.PauseTransferResponse.fromBuffer);
  static final _$resumeTransfer =
      $grpc.ClientMethod<$0.ResumeTransferRequest, $0.ResumeTransferResponse>(
          '/peerlink.v1.DesktopLocalNodeService/ResumeTransfer',
          ($0.ResumeTransferRequest value) => value.writeToBuffer(),
          $0.ResumeTransferResponse.fromBuffer);
  static final _$setBandwidthLimit = $grpc.ClientMethod<
          $0.SetBandwidthLimitRequest, $0.SetBandwidthLimitResponse>(
      '/peerlink.v1.DesktopLocalNodeService/SetBandwidthLimit',
      ($0.SetBandwidthLimitRequest value) => value.writeToBuffer(),
      $0.SetBandwidthLimitResponse.fromBuffer);
  static final _$getTransfer =
      $grpc.ClientMethod<$0.GetTransferRequest, $0.GetTransferResponse>(
          '/peerlink.v1.DesktopLocalNodeService/GetTransfer',
          ($0.GetTransferRequest value) => value.writeToBuffer(),
          $0.GetTransferResponse.fromBuffer);
  static final _$listTransfers =
      $grpc.ClientMethod<$0.ListTransfersRequest, $0.ListTransfersResponse>(
          '/peerlink.v1.DesktopLocalNodeService/ListTransfers',
          ($0.ListTransfersRequest value) => value.writeToBuffer(),
          $0.ListTransfersResponse.fromBuffer);
  static final _$revealInFolder =
      $grpc.ClientMethod<$0.RevealInFolderRequest, $0.RevealInFolderResponse>(
          '/peerlink.v1.DesktopLocalNodeService/RevealInFolder',
          ($0.RevealInFolderRequest value) => value.writeToBuffer(),
          $0.RevealInFolderResponse.fromBuffer);
}

@$pb.GrpcServiceName('peerlink.v1.DesktopLocalNodeService')
abstract class DesktopLocalNodeServiceBase extends $grpc.Service {
  $core.String get $name => 'peerlink.v1.DesktopLocalNodeService';

  DesktopLocalNodeServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.AuthenticateIpcRequest,
            $0.AuthenticateIpcResponse>(
        'Authenticate',
        authenticate_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AuthenticateIpcRequest.fromBuffer(value),
        ($0.AuthenticateIpcResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetNodeStatusRequest, $0.GetNodeStatusResponse>(
            'GetStatus',
            getStatus_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetNodeStatusRequest.fromBuffer(value),
            ($0.GetNodeStatusResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.NodeEventSubscriptionRequest, $0.NodeEvent>(
            'SubscribeEvents',
            subscribeEvents_Pre,
            false,
            true,
            ($core.List<$core.int> value) =>
                $0.NodeEventSubscriptionRequest.fromBuffer(value),
            ($0.NodeEvent value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.RestartNodeRequest, $0.RestartNodeResponse>(
            'Restart',
            restart_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.RestartNodeRequest.fromBuffer(value),
            ($0.RestartNodeResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.StopNodeRequest, $0.StopNodeResponse>(
        'Stop',
        stop_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.StopNodeRequest.fromBuffer(value),
        ($0.StopNodeResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.InitiateSendRequest, $0.InitiateSendResponse>(
            'InitiateSend',
            initiateSend_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.InitiateSendRequest.fromBuffer(value),
            ($0.InitiateSendResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CancelTransferRequest,
            $0.CancelTransferResponse>(
        'CancelTransfer',
        cancelTransfer_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CancelTransferRequest.fromBuffer(value),
        ($0.CancelTransferResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.PauseTransferRequest, $0.PauseTransferResponse>(
            'PauseTransfer',
            pauseTransfer_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.PauseTransferRequest.fromBuffer(value),
            ($0.PauseTransferResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ResumeTransferRequest,
            $0.ResumeTransferResponse>(
        'ResumeTransfer',
        resumeTransfer_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ResumeTransferRequest.fromBuffer(value),
        ($0.ResumeTransferResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SetBandwidthLimitRequest,
            $0.SetBandwidthLimitResponse>(
        'SetBandwidthLimit',
        setBandwidthLimit_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SetBandwidthLimitRequest.fromBuffer(value),
        ($0.SetBandwidthLimitResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetTransferRequest, $0.GetTransferResponse>(
            'GetTransfer',
            getTransfer_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetTransferRequest.fromBuffer(value),
            ($0.GetTransferResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListTransfersRequest, $0.ListTransfersResponse>(
            'ListTransfers',
            listTransfers_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListTransfersRequest.fromBuffer(value),
            ($0.ListTransfersResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RevealInFolderRequest,
            $0.RevealInFolderResponse>(
        'RevealInFolder',
        revealInFolder_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RevealInFolderRequest.fromBuffer(value),
        ($0.RevealInFolderResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.AuthenticateIpcResponse> authenticate_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AuthenticateIpcRequest> $request) async {
    return authenticate($call, await $request);
  }

  $async.Future<$0.AuthenticateIpcResponse> authenticate(
      $grpc.ServiceCall call, $0.AuthenticateIpcRequest request);

  $async.Future<$0.GetNodeStatusResponse> getStatus_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetNodeStatusRequest> $request) async {
    return getStatus($call, await $request);
  }

  $async.Future<$0.GetNodeStatusResponse> getStatus(
      $grpc.ServiceCall call, $0.GetNodeStatusRequest request);

  $async.Stream<$0.NodeEvent> subscribeEvents_Pre($grpc.ServiceCall $call,
      $async.Future<$0.NodeEventSubscriptionRequest> $request) async* {
    yield* subscribeEvents($call, await $request);
  }

  $async.Stream<$0.NodeEvent> subscribeEvents(
      $grpc.ServiceCall call, $0.NodeEventSubscriptionRequest request);

  $async.Future<$0.RestartNodeResponse> restart_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RestartNodeRequest> $request) async {
    return restart($call, await $request);
  }

  $async.Future<$0.RestartNodeResponse> restart(
      $grpc.ServiceCall call, $0.RestartNodeRequest request);

  $async.Future<$0.StopNodeResponse> stop_Pre($grpc.ServiceCall $call,
      $async.Future<$0.StopNodeRequest> $request) async {
    return stop($call, await $request);
  }

  $async.Future<$0.StopNodeResponse> stop(
      $grpc.ServiceCall call, $0.StopNodeRequest request);

  $async.Future<$0.InitiateSendResponse> initiateSend_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.InitiateSendRequest> $request) async {
    return initiateSend($call, await $request);
  }

  $async.Future<$0.InitiateSendResponse> initiateSend(
      $grpc.ServiceCall call, $0.InitiateSendRequest request);

  $async.Future<$0.CancelTransferResponse> cancelTransfer_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.CancelTransferRequest> $request) async {
    return cancelTransfer($call, await $request);
  }

  $async.Future<$0.CancelTransferResponse> cancelTransfer(
      $grpc.ServiceCall call, $0.CancelTransferRequest request);

  $async.Future<$0.PauseTransferResponse> pauseTransfer_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.PauseTransferRequest> $request) async {
    return pauseTransfer($call, await $request);
  }

  $async.Future<$0.PauseTransferResponse> pauseTransfer(
      $grpc.ServiceCall call, $0.PauseTransferRequest request);

  $async.Future<$0.ResumeTransferResponse> resumeTransfer_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ResumeTransferRequest> $request) async {
    return resumeTransfer($call, await $request);
  }

  $async.Future<$0.ResumeTransferResponse> resumeTransfer(
      $grpc.ServiceCall call, $0.ResumeTransferRequest request);

  $async.Future<$0.SetBandwidthLimitResponse> setBandwidthLimit_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SetBandwidthLimitRequest> $request) async {
    return setBandwidthLimit($call, await $request);
  }

  $async.Future<$0.SetBandwidthLimitResponse> setBandwidthLimit(
      $grpc.ServiceCall call, $0.SetBandwidthLimitRequest request);

  $async.Future<$0.GetTransferResponse> getTransfer_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetTransferRequest> $request) async {
    return getTransfer($call, await $request);
  }

  $async.Future<$0.GetTransferResponse> getTransfer(
      $grpc.ServiceCall call, $0.GetTransferRequest request);

  $async.Future<$0.ListTransfersResponse> listTransfers_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListTransfersRequest> $request) async {
    return listTransfers($call, await $request);
  }

  $async.Future<$0.ListTransfersResponse> listTransfers(
      $grpc.ServiceCall call, $0.ListTransfersRequest request);

  $async.Future<$0.RevealInFolderResponse> revealInFolder_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RevealInFolderRequest> $request) async {
    return revealInFolder($call, await $request);
  }

  $async.Future<$0.RevealInFolderResponse> revealInFolder(
      $grpc.ServiceCall call, $0.RevealInFolderRequest request);
}
