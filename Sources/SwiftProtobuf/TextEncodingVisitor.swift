// ProtobufRuntime/Sources/Protobuf/ProtobufTextEncoding.swift - Text format encoding support
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
// -----------------------------------------------------------------------------
///
/// Text format serialization engine.
///
// -----------------------------------------------------------------------------

import Foundation

public struct TextEncodingVisitor: Visitor {
    private var encoder: TextEncoder
    public var result: String {return encoder.result}
    private var nameResolver: (Int) -> String?

    public init(message: Message) throws {
        self.encoder = TextEncoder()
        self.nameResolver =
            ProtoNameResolvers.protoFieldNameResolver(for: message)
        try withAbstractVisitor {(visitor: inout Visitor) in
            try message.traverse(visitor: &visitor)
        }
    }

    public init(message: Message, encoder: TextEncoder) throws {
        self.encoder = encoder
        self.nameResolver =
            ProtoNameResolvers.protoFieldNameResolver(for: message)
        try withAbstractVisitor {(visitor: inout Visitor) in
            try message.traverse(visitor: &visitor)
        }
    }

    mutating public func withAbstractVisitor(clause: (inout Visitor) throws -> ()) throws {
        var visitor: Visitor = self
        try clause(&visitor)
        encoder.text = (visitor as! TextEncodingVisitor).encoder.text
    }

    mutating public func visitUnknown(bytes: Data) {
        // TODO: Does text encoding have any provision for representing proto2 unknown field?
    }

    mutating public func visitSingularField<S: FieldType>(fieldType: S.Type, value: S.BaseType, protoFieldNumber: Int) throws {
        let protoFieldName = try self.protoFieldName(for: protoFieldNumber)
        encoder.startField(name: protoFieldName)
        try S.serializeTextValue(encoder: encoder, value: value)
        encoder.endField()
    }

    mutating public func visitRepeatedField<S: FieldType>(fieldType: S.Type, value: [S.BaseType], protoFieldNumber: Int) throws {
        let protoFieldName = try self.protoFieldName(for: protoFieldNumber)
        for v in value {
            encoder.startField(name: protoFieldName)
            try S.serializeTextValue(encoder: encoder, value: v)
            encoder.endField()
        }
    }

    mutating public func visitPackedField<S: FieldType>(fieldType: S.Type, value: [S.BaseType], protoFieldNumber: Int) throws {
        try visitRepeatedField(fieldType: fieldType, value: value, protoFieldNumber: protoFieldNumber)
    }

    mutating public func visitSingularMessageField<M: Message>(value: M, protoFieldNumber: Int) throws {
        let protoFieldName = try self.protoFieldName(for: protoFieldNumber)
        encoder.startField(name: protoFieldName, dropColon: true)
        try M.serializeTextValue(encoder: encoder, value: value)
        encoder.endField()
    }

    mutating public func visitRepeatedMessageField<M: Message>(value: [M], protoFieldNumber: Int) throws {
        let protoFieldName = try self.protoFieldName(for: protoFieldNumber)
        for v in value {
            encoder.startField(name: protoFieldName, dropColon: true)
            try M.serializeTextValue(encoder: encoder, value: v)
            encoder.endField()
        }
    }

    mutating public func visitSingularGroupField<G: Message>(value: G, protoFieldNumber: Int) throws {
        try visitSingularMessageField(value: value, protoFieldNumber: protoFieldNumber)
    }

    mutating public func visitRepeatedGroupField<G: Message>(value: [G], protoFieldNumber: Int) throws {
        try visitRepeatedMessageField(value: value, protoFieldNumber: protoFieldNumber)
    }

    mutating public func visitMapField<KeyType: MapKeyType, ValueType: MapValueType>(fieldType: ProtobufMap<KeyType, ValueType>.Type, value: ProtobufMap<KeyType, ValueType>.BaseType, protoFieldNumber: Int) throws  where KeyType.BaseType: Hashable {
        let protoFieldName = try self.protoFieldName(for: protoFieldNumber)
        for (k,v) in value {
            encoder.startField(name: protoFieldName, dropColon: true)
            encoder.startObject()
            encoder.startField(name: "key")
            try KeyType.serializeTextValue(encoder: encoder, value: k)
            encoder.endField()
            encoder.startField(name: "value")
            try ValueType.serializeTextValue(encoder: encoder, value: v)
            encoder.endField()
            encoder.endObject()
            encoder.endField()
        }
    }

    /// Helper function that throws an error if the field number could not be
    /// resolved.
    private func protoFieldName(for number: Int) throws -> String {
        if let protoName = nameResolver(number) {
            return protoName
        }
        throw EncodingError.missingFieldNames
    }
}
