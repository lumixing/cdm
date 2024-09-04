package decode

import "core:encoding/endian"
import "core:fmt"
import "core:os"
import "core:time"

ENDIAN: endian.Byte_Order : .Big
DM_FLAG: u8 : 0b1000_0000
RECV_FLAG: u8 : 0b1000_0000
PIN_FLAG: u8 : 0b0100_0000

FileFlag :: enum {
	DirectMessages,
}
FileFlags :: bit_set[FileFlag]

Snowflake :: distinct u64

CDM_File :: struct {
	flags:      FileFlags,
	channel_id: Snowflake,
	user_ids:   []Snowflake,
	guild_id:   Maybe(Snowflake),
	messages:   []Message,
}

Message :: struct {
	id:                Snowflake,
	user_id_index:     Maybe(u16),
	basic_attachments: []string,
	smart_attachments: []SmartAttachment,
	flags:             MessageFlags,
	content:           string,
}

MessageFlag :: enum {
	Receiver,
	Pinned,
}
MessageFlags :: bit_set[MessageFlag]

SmartAttachment :: struct {
	channel_id:       Snowflake,
	id:               Snowflake,
	name:             string,
	expire_timestamp: time.Time,
	issued_timestamp: time.Time,
	signature:        [4]u64,
}

cdm_parse :: proc(data: []byte) -> CDM_File {
	current := 0
	cdm: CDM_File

	flags_byte := data[current]
	current += 1
	if flags_byte & DM_FLAG != 0 {
		cdm.flags += {.DirectMessages}
	}

	cdm.channel_id = Snowflake(get_u64(data, &current))
	user_ids: [dynamic]Snowflake

	if .DirectMessages in cdm.flags {
		append(&user_ids, Snowflake(get_u64(data, &current)))
		append(&user_ids, Snowflake(get_u64(data, &current)))
	} else {
		cdm.guild_id = Snowflake(get_u64(data, &current))
		user_ids_len := get_u16(data, &current)
		for _ in 0 ..< user_ids_len {
			append(&user_ids, Snowflake(get_u64(data, &current)))
		}
	}
	cdm.user_ids = user_ids[:]

	messages: [dynamic]Message
	messages_len := get_u32(data, &current)
	for _ in 0 ..< messages_len {
		message: Message
		message.id = Snowflake(get_u64(data, &current))

		if .DirectMessages not_in cdm.flags {
			message.user_id_index = get_u16(data, &current)
		}

		basic_att: [dynamic]string
		basic_att_len := get_u8(data, &current)
		for _ in 0 ..< basic_att_len {
			append(&basic_att, get_str(data, &current))
		}
		message.basic_attachments = basic_att[:]

		smart_att: [dynamic]SmartAttachment
		smart_att_len := get_u8(data, &current)
		for _ in 0 ..< smart_att_len {
			att: SmartAttachment
			att.channel_id = Snowflake(get_u64(data, &current))
			att.id = Snowflake(get_u64(data, &current))
			att.name = get_str(data, &current)
			att.expire_timestamp = time.unix(i64(get_u32(data, &current)), 0)
			att.issued_timestamp = time.unix(i64(get_u32(data, &current)), 0)
			for i in 0 ..< 4 {
				att.signature[i] = get_u64(data, &current)
			}
			append(&smart_att, att)
		}
		message.smart_attachments = smart_att[:]

		flags_byte := get_u8(data, &current)
		if flags_byte & RECV_FLAG != 0 {
			message.flags += {.Receiver}
		}
		if flags_byte & PIN_FLAG != 0 {
			message.flags += {.Pinned}
		}

		message.content = get_str(data, &current)

		append(&messages, message)
	}
	cdm.messages = messages[:]

	return cdm
}

main :: proc() {
	data, ok := os.read_entire_file("out/getimis.cdm")
	if !ok {
		panic("could not read data")
	}

	cdm := cdm_parse(data)

	fmt.printfln("%#v", cdm.messages[1])
	smart_att_url(cdm.messages[1].smart_attachments[0])
}

get_u64 :: proc(data: []byte, current: ^int) -> u64 {
	size := size_of(u64)
	buf := data[current^:][:size]
	current^ += size

	v, ok := endian.get_u64(buf[:], ENDIAN)
	if !ok {
		panic("could not get u64")
	}

	return v
}

get_u32 :: proc(data: []byte, current: ^int) -> u32 {
	size := size_of(u32)
	buf := data[current^:][:size]
	current^ += size

	v, ok := endian.get_u32(buf[:], ENDIAN)
	if !ok {
		panic("could not get u32")
	}

	return v
}

get_u16 :: proc(data: []byte, current: ^int) -> u16 {
	size := size_of(u16)
	buf := data[current^:][:size]
	current^ += size

	v, ok := endian.get_u16(buf[:], ENDIAN)
	if !ok {
		panic("could not get u16")
	}

	return v
}

get_u8 :: proc(data: []byte, current: ^int) -> u8 {
	defer current^ += 1
	return data[current^]
}

get_str :: proc(data: []byte, current: ^int) -> string {
	len := int(get_u16(data, current))
	str := data[current^:current^ + len]
	current^ += len
	return string(str)
}

snowflake_get_timestamp :: proc(snowflake: Snowflake) -> time.Time {
	ms := (u64(snowflake) >> 22) + 1420070400000
	return time.unix(i64(ms / 1000), 0)
}

smart_att_url :: proc(att: SmartAttachment) -> string {
	fmt.printfln("%x", time.to_unix_seconds(att.expire_timestamp))
	fmt.printfln("%x", time.to_unix_seconds(att.issued_timestamp))
	fmt.printfln(
		"%x\n%x\n%x\n%x",
		att.signature[0],
		att.signature[1],
		att.signature[2],
		att.signature[3],
	)
	return ""
}
