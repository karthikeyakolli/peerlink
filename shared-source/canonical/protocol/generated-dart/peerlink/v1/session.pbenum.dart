// This is a generated file - do not edit.
//
// Generated from peerlink/v1/session.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class SessionState extends $pb.ProtobufEnum {
  static const SessionState SESSION_STATE_UNSPECIFIED =
      SessionState._(0, _omitEnumNames ? '' : 'SESSION_STATE_UNSPECIFIED');
  static const SessionState SESSION_STATE_INITIATING =
      SessionState._(1, _omitEnumNames ? '' : 'SESSION_STATE_INITIATING');
  static const SessionState SESSION_STATE_ESTABLISHED =
      SessionState._(2, _omitEnumNames ? '' : 'SESSION_STATE_ESTABLISHED');
  static const SessionState SESSION_STATE_REKEYING =
      SessionState._(3, _omitEnumNames ? '' : 'SESSION_STATE_REKEYING');
  static const SessionState SESSION_STATE_CLOSING =
      SessionState._(4, _omitEnumNames ? '' : 'SESSION_STATE_CLOSING');
  static const SessionState SESSION_STATE_CLOSED =
      SessionState._(5, _omitEnumNames ? '' : 'SESSION_STATE_CLOSED');
  static const SessionState SESSION_STATE_REJECTED =
      SessionState._(6, _omitEnumNames ? '' : 'SESSION_STATE_REJECTED');

  static const $core.List<SessionState> values = <SessionState>[
    SESSION_STATE_UNSPECIFIED,
    SESSION_STATE_INITIATING,
    SESSION_STATE_ESTABLISHED,
    SESSION_STATE_REKEYING,
    SESSION_STATE_CLOSING,
    SESSION_STATE_CLOSED,
    SESSION_STATE_REJECTED,
  ];

  static final $core.List<SessionState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static SessionState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SessionState._(super.value, super.name);
}

class TransportType extends $pb.ProtobufEnum {
  static const TransportType TRANSPORT_TYPE_UNSPECIFIED =
      TransportType._(0, _omitEnumNames ? '' : 'TRANSPORT_TYPE_UNSPECIFIED');
  static const TransportType TRANSPORT_TYPE_DIRECT_QUIC =
      TransportType._(1, _omitEnumNames ? '' : 'TRANSPORT_TYPE_DIRECT_QUIC');
  static const TransportType TRANSPORT_TYPE_DIRECT_TCP_TLS =
      TransportType._(2, _omitEnumNames ? '' : 'TRANSPORT_TYPE_DIRECT_TCP_TLS');
  static const TransportType TRANSPORT_TYPE_RELAY_TURN =
      TransportType._(3, _omitEnumNames ? '' : 'TRANSPORT_TYPE_RELAY_TURN');

  static const $core.List<TransportType> values = <TransportType>[
    TRANSPORT_TYPE_UNSPECIFIED,
    TRANSPORT_TYPE_DIRECT_QUIC,
    TRANSPORT_TYPE_DIRECT_TCP_TLS,
    TRANSPORT_TYPE_RELAY_TURN,
  ];

  static final $core.List<TransportType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static TransportType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TransportType._(super.value, super.name);
}

class HandshakePhase extends $pb.ProtobufEnum {
  static const HandshakePhase HANDSHAKE_PHASE_UNSPECIFIED =
      HandshakePhase._(0, _omitEnumNames ? '' : 'HANDSHAKE_PHASE_UNSPECIFIED');
  static const HandshakePhase HANDSHAKE_PHASE_SYN =
      HandshakePhase._(1, _omitEnumNames ? '' : 'HANDSHAKE_PHASE_SYN');
  static const HandshakePhase HANDSHAKE_PHASE_SYN_ACK =
      HandshakePhase._(2, _omitEnumNames ? '' : 'HANDSHAKE_PHASE_SYN_ACK');
  static const HandshakePhase HANDSHAKE_PHASE_ACK =
      HandshakePhase._(3, _omitEnumNames ? '' : 'HANDSHAKE_PHASE_ACK');
  static const HandshakePhase HANDSHAKE_PHASE_REJECT =
      HandshakePhase._(4, _omitEnumNames ? '' : 'HANDSHAKE_PHASE_REJECT');

  static const $core.List<HandshakePhase> values = <HandshakePhase>[
    HANDSHAKE_PHASE_UNSPECIFIED,
    HANDSHAKE_PHASE_SYN,
    HANDSHAKE_PHASE_SYN_ACK,
    HANDSHAKE_PHASE_ACK,
    HANDSHAKE_PHASE_REJECT,
  ];

  static final $core.List<HandshakePhase?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static HandshakePhase? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const HandshakePhase._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
