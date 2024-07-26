#!/bin/env python3

import sys

import fastjsonschema
sys.modules['jsonschema'] = fastjsonschema

from nlspec import SpecFamily

def sanitize(name):
    return name.replace('-', '_')

def print_const(const):
    if const['type'] == 'enum':
        # SpecEnumSet
        name = sanitize(const['name'])
        print(f'pub const {name} = enum(u8) {{')
        for _, entry in const.entries.items():
            entry_name = sanitize(entry.name)
            if entry_name == 'unreachable': # rtm_type.rt_route
                entry_name = 'unreachable_'
            print(f'    {entry_name},')
        print('};')
    elif const['type'] == 'struct':
        # SpecStruct
        name = sanitize(const['name'])
        print(f'pub const {name} = extern struct {{')
        for field in const.members:
            field_name = sanitize(field.name)
            if field.type == 'pad' or field.type == 'binary':
                print(f'    {field_name}: [{field.len}]u8,')
            elif field.enum:
                if 'enum-as-flags' in field:
                    size = field.type.removeprefix('u')
                    print(f'    {field_name}: std.bit_set.IntegerBitSet({size}),')
                else:
                    field_type = sanitize(field.enum)
                    print(f'    {field_name}: {field_type},')
            else:
                field_type = field.type
                if field_type.startswith('s'):
                    field_type = 'i' +  field_type[1:]
                print(f'    {field_name}: {field_type},')
        print('};')
    elif const['type'] == 'flags':
        # SpecEnumSet
        name = sanitize(const['name'])
        print(f'pub const {name} = struct {{')
        for _, entry in const.entries.items():
            entry_name = sanitize(entry.name).upper()
            print(f'    pub const {entry_name} = {entry.value};')
        print('};')
    else:
        raise Exception(f'unknown type {const["type"]}')

def op_name(name):
    name = sanitize(name).title()
    prefix = name[:3]
    if prefix == 'New' or prefix == 'Del' or prefix == 'Get' or prefix == 'Set':
        return prefix + name[3].upper() + name[4:]
    return name

def print_op(op):
    name = op_name(op['name'])
    print(f'pub const {name}Request = msg.Request(@enumFromInt({op.req_value}), {op.fixed_header});')
    if op.rsp_value:
        print(f'pub const {name}Response = msg.Response(@enumFromInt({op.rsp_value}), {op.fixed_header});')

def main(spec):
    print(f'''/// This file is generated from the {spec.name} spec; do not edit.

const std = @import("std");
pub const msg = @import("message.zig");''')
    for _, const in spec.consts.items():
        print('')
        print_const(const)

    print('')
    for _, op in spec.req_by_value.items():
        print_op(op)

    print('\n pub const Ops = .{')
    for _, op in spec.req_by_value.items():
        name = op_name(op['name'])
        res = name if op.rsp_value else 'msg.Ack'
        print(f'    .{{ {name}Request, {res}Response }},')
    print('};')

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print('missing spec path')
        sys.exit(1)

    main(SpecFamily(sys.argv[1]))
