#!/usr/bin/env python3
"""一つのJSONスキーマから型・書込・読込・参照検査を生成する。"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TYPES = {'u8':'uint8_t','u32':'uint32_t','u64':'uint64_t','i64':'int64_t','f32':'float','f64':'double','bool':'bool','string':'std::string'}
WIDTH = {'u8':1,'u32':4,'u64':8,'i64':8,'f32':4,'f64':8,'bool':1,'string':4}

def generate():
    schema=json.loads((ROOT/'cpp/content/schema/run.json').read_text(encoding='utf-8'))
    assert set(schema)=={'schema_version','format_version','abi_version','records','enums','event_fields','includes'}
    for include in schema['includes']:
        assert Path(include).name==include and include.endswith('.json')
        extra=json.loads((ROOT/'cpp/content/schema'/include).read_text(encoding='utf-8'))
        assert set(extra)=={'records','enums'} and not set(extra['enums']) & set(schema['enums'])
        schema['records'] += extra['records']
        schema['enums'].update(extra['enums'])
    enums=['// 共通スキーマから生成。直接編集しない。','#pragma once','#include <cstdint>','#include <string_view>','namespace speed {']
    for name, entries in schema['enums'].items():
        assert len({e['name'] for e in entries})==len(entries) and len({e['value'] for e in entries})==len(entries)
        enums += [f'enum class {name} : uint32_t {{'+','.join(f"{e['name']}={i}" for i,e in enumerate(entries))+',Count};']
        enums += [f'inline const char *symbol_name({name} value) {{', '    switch(value) {']
        enums += [f'    case {name}::{e["name"]}: return {json.dumps(e["value"])};' for e in entries]
        enums += ['    default: return "";','    }','}']
        enums += [f'inline bool parse_symbol(std::string_view value, {name} &out) {{']
        enums += [f'    if (value=={json.dumps(e["value"])}) {{out={name}::{e["name"]};return true;}}' for e in entries]
        enums += ['    return false;','}']
    enums += ['inline bool event_field_allowed(EventType type, std::string_view field) {','    switch(type) {']
    for event in schema['enums']['EventType']:
        allowed=schema['event_fields'][event['value']]
        condition=' || '.join(f'field=={json.dumps(field)}' for field in allowed) or 'false'
        enums += [f'    case EventType::{event["name"]}: return {condition};']
    enums += ['    default: return false;','    }','}']
    enums += ['}']
    records=schema['records']; names={r['name'] for r in records}
    assert len(names)==len(records) and len({r['section'] for r in records})==len(records)
    for record in records:
        assert set(record)<= {'name','section','fields','enabled','version'}
        keys=set()
        for field in record['fields']:
            assert set(field)<= {'name','type','min','max','source','ref','native','runtime','config','value','multiplier'}
            assert field['name'].isidentifier() and field['type'] in TYPES
            assert field.get('ref',record['name']) in names
            assert field.get('source',field['name']) not in keys
            keys.add(field.get('source',field['name']))
    cpp=['// 共通スキーマから生成。直接編集しない。','#pragma once','#include <cstdint>','#include <string>','#include <vector>','namespace speed {']
    # 読込処理は使う場所が限られるので、広くincludeされる型定義から分ける。
    reader=['// 共通スキーマから生成。直接編集しない。','#pragma once','#include "run_schema.h"','#include "../binary_reader.h"','#include "../runtime_data.h"','#include "../../state/run_state.h"','#include <unordered_set>','namespace speed {']
    for rec in records:
        cpp += [f'struct {rec["name"]} {{']+[f'    {TYPES[f["type"]]} {f["name"]}{{}};' for f in rec['fields']]+['};']
        reader += [f'inline bool read(BinaryReader &input, {rec["name"]} &out) {{']
        for f in rec['fields']:
            reader += [f'    if (!input.read_{f["type"]}(out.{f["name"]})) return false;']
            for constraint,op in [('min','<'),('max','>')]:
                if constraint in f:reader += [f'    if (out.{f["name"]} {op} {f[constraint]}) return false;']
        reader += ['    return true;','}']
    cpp+=['struct ContentRecords {']+[f'    std::vector<{r["name"]}> {r["name"]}_rows;' for r in records]+['};']
    reader+=['inline bool read_section(uint32_t kind, uint32_t version, uint32_t count, BinaryReader &input, ContentRecords &out) {','    switch(kind) {']
    for rec in records:
        n=rec['name'];minimum=sum(WIDTH[f['type']] for f in rec['fields'])
        reader += [f'    case {rec["section"]}: {{',f'        if (version != {rec.get("version",1)}) return false;']
        if not rec.get('enabled',True):reader+=['        if (count) return false;']
        reader += [f'        if (count > input.remaining()/{minimum}) return false;',f'        for (uint32_t i=0; i<count; ++i) {{ {n} row; if (!read(input,row)) return false; out.{n}_rows.push_back(std::move(row)); }}','        return input.remaining()==0;','    }']
    reader+=['    default: return false;','    }','}']
    reader+=['inline bool validate_references(const ContentRecords &data) {']
    for rec in records:
        n=rec['name'];reader += [f'    std::unordered_set<uint32_t> {n}_ids;',f'    for (const auto &row:data.{n}_rows) if (!{n}_ids.insert(row.id).second) return false;']
    for rec in records:
        for f in rec['fields']:
            if 'ref' in f:reader += [f'    for (const auto &row:data.{rec["name"]}_rows) if (!{f["ref"]}_ids.count(row.{f["name"]})) return false;']
    reader+=['    return true;','}']
    reader+=['inline void apply_config(const RunConfig &config, godot::RunState &state) {']
    for f in records[0]['fields']:
        if 'runtime' in f:reader += [f'    state.{f["runtime"]}=config.{f["name"]};']
    reader+=['}']
    reader+=['inline godot::Dictionary config_snapshot(const RunConfig &config) {','    godot::Dictionary out;']
    for f in records[0]['fields']:
        reader += [f'    out["{f["name"]}"]=config.{f["name"]};']
    reader+=['    return out;','}']
    reader+=['inline EnemyDefinition to_enemy(const EnemyRecord &row, const godot::StringName &id) {','    EnemyDefinition out; out.id=id; out.spawn_ready=true; out.scaling.ready=true;']
    for f in next(r for r in records if r['name']=='EnemyRecord')['fields']:
        if 'native' in f:reader += [f'    out.{f["native"]}=row.{f["name"]};']
    reader+=['    out.kind=static_cast<EnemyDefinition::Kind>(row.kind);','    return out;','}','}']
    cpp+=[f'inline constexpr uint32_t FORMAT_VERSION={schema["format_version"]}, ABI_VERSION={schema["abi_version"]}, SECTION_COUNT={len(records)};','}']
    gd=['## 共通スキーマから生成。直接編集しない。','extends RefCounted','',f'const SCHEMA = {json.dumps(schema,ensure_ascii=False).replace("false","false").replace("true","true")}']
    enum_values={name:{entry['name']:index for index,entry in enumerate(entries)} for name,entries in schema['enums'].items()}
    gd += ['const ENUMS = preload("res://scripts/data_types/generated/run_ids.gd").ENUMS', GD_WRITER]
    runtime_ids = '## 共通スキーマから生成。直接編集しない。\nextends RefCounted\nconst ENUMS = ' + json.dumps(enum_values,ensure_ascii=False) + '\n'
    return {'cpp/content/generated/combat_ids.h':'\n'.join(enums)+'\n','cpp/content/generated/run_schema.h':'\n'.join(cpp)+'\n','cpp/content/generated/run_schema_read.h':'\n'.join(reader)+'\n','speed/tools/content/generated/run_schema.gd':'\n'.join(gd).rstrip()+'\n','speed/scripts/data_types/generated/run_ids.gd':runtime_ids}

GD_WRITER = r'''
static func write_content(data: Dictionary, input_sha256: PackedByteArray) -> PackedByteArray:
	if data.size() != SCHEMA.records.size() or input_sha256.size() != 32: return PackedByteArray()
	var ids := {}
	for record in SCHEMA.records:
		if not data.has(record.name) or not data[record.name] is Array: return PackedByteArray()
		if not record.get("enabled", true) and not data[record.name].is_empty(): return PackedByteArray()
		ids[record.name] = {}
		for row in data[record.name]:
			if not row is Dictionary or not _valid_record(row, record): return PackedByteArray()
			if ids[record.name].has(row.id): return PackedByteArray()
			ids[record.name][row.id] = true
	for record in SCHEMA.records:
		for row in data[record.name]:
			for field in record.fields:
				if field.has("ref") and not ids[field.ref].has(row[field.get("source",field.name)]): return PackedByteArray()
	var payload := StreamPeerBuffer.new()
	payload.big_endian = false
	var sections := []
	for record in SCHEMA.records:
		var start := payload.get_position()
		for row in data[record.name]:
			for field in record.fields:
				_put(payload,field.type,row[field.get("source",field.name)]*field.multiplier if field.has("multiplier") else row[field.get("source",field.name)])
		sections.append([record.section,start,payload.get_position()-start,data[record.name].size(),record.get("version",1)])
	var output := StreamPeerBuffer.new()
	output.big_endian = false
	output.put_data("SPDRUN01".to_ascii_buffer())
	output.put_u32(SCHEMA.format_version)
	output.put_u32(SCHEMA.abi_version)
	output.put_u32(sections.size())
	output.put_u32(0)
	output.put_data(input_sha256)
	output.put_data(sha256(payload.data_array))
	var begin := 88+32*sections.size()
	for section in sections:
		output.put_u32(section[0])
		output.put_u32(section[4])
		output.put_u64(begin+section[1])
		output.put_u64(section[2])
		output.put_u32(section[3])
		output.put_u32(0)
	output.put_data(payload.data_array)
	return output.data_array

static func sha256(bytes: PackedByteArray) -> PackedByteArray:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish()

static func _valid_record(row: Dictionary, record: Dictionary) -> bool:
	if row.size()!=record.fields.size(): return false
	for field in record.fields:
		var key: String = field.get("source",field.name)
		if not row.has(key): return false
		var value = row[key]
		match field.type:
			"string":
				if not value is String or value.to_utf8_buffer().size()>4294967295: return false
			"bool":
				if not value is bool: return false
			"u8", "u32", "u64", "i64":
				if not value is int: return false
				if field.type.begins_with("u") and value<0: return false
				if field.type=="u8" and value>255: return false
				if field.type=="u32" and value>4294967295: return false
			"f32", "f64":
				if not (value is float or value is int) or not is_finite(value): return false
				if field.type=="f32" and absf(value)>3.4028234663852886e38: return false
			_:
				return false
		if field.has("min") and value<field.min: return false
		if field.has("max") and value>field.max: return false
	return true

static func _put(out: StreamPeerBuffer, type: String, value) -> void:
	match type:
		"u8", "bool": out.put_u8(int(value))
		"u32": out.put_u32(value)
		"u64": out.put_u64(value)
		"i64": out.put_64(value)
		"f32": out.put_float(value)
		"f64": out.put_double(value)
		"string":
			var bytes: PackedByteArray = value.to_utf8_buffer()
			out.put_u32(bytes.size())
			out.put_data(bytes)
'''

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    outputs=generate()
    if args.check:
        return 0 if all((ROOT/p).exists() and (ROOT/p).read_text(encoding='utf-8')==s for p,s in outputs.items()) else 1
    for path,text in outputs.items():
        destination=ROOT/path;destination.parent.mkdir(parents=True,exist_ok=True);destination.write_text(text,encoding='utf-8',newline='\n')
    return 0
if __name__=='__main__':raise SystemExit(main())
