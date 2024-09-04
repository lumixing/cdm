package encode

import "core:bytes"
import "core:encoding/endian"
import "core:encoding/json"
import "core:fmt"
import "core:net"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"

DM_FLAG: u8 : 0b1000_0000
USERNAMES_FLAG: u8 : 0b0100_0000

RECV_FLAG: u8 : 0b1000_0000
PINNED_FLAG: u8 : 0b0100_0000

Data :: struct {
	guild:    struct {
		id: string,
	},
	channel:  struct {
		id: string,
	},
	messages: []Message,
}

Message :: struct {
	id:          string,
	content:     string,
	author:      struct {
		id:   string,
		name: string,
	},
	pinned:      bool `json:"isPinned"`,
	attachments: []struct {
		url: string,
	},
}

SmartAttachment :: struct {
	channel_id: string,
	id:         string,
	name:       string,
	expire:     string,
	issue:      string,
	signature:  string,
}

main :: proc() {
	fmt.println("reading input data...")
	data, ok := os.read_entire_file(os.args[1])
	if !ok {
		panic("could not read input file")
	}

	fmt.println("unmarshaling input data...")
	file: Data
	json.unmarshal(data, &file)
	buffer := new(bytes.Buffer)

	keep_usernames := true

	user_ids: []string
	flags: u8

	if file.guild.id == "0" {
		flags |= DM_FLAG
	}
	if keep_usernames {
		flags |= USERNAMES_FLAG
	}

	write_u8(buffer, flags)
	write_u64_str(buffer, file.channel.id)

	fmt.println("getting user ids")
	if flags & DM_FLAG != 0 {
		recv := file.messages[0].author.id
		write_u64_str(buffer, recv)
		if flags & USERNAMES_FLAG != 0 {
			write_str(buffer, file.messages[0].author.name)
		}

		for msg in file.messages {
			if msg.author.id != recv {
				write_u64_str(buffer, msg.author.id)
				if flags & USERNAMES_FLAG != 0 {
					write_str(buffer, msg.author.name)
				}
				break
			}
		}
	} else {
		write_u64_str(buffer, file.guild.id)

		dyn_user_ids: [dynamic]string
		addr := bytes.buffer_length(buffer)

		for msg in file.messages {
			if !slice.contains(dyn_user_ids[:], msg.author.id) {
				append(&dyn_user_ids, msg.author.id)
				write_u64_str(buffer, msg.author.id)
				if flags & USERNAMES_FLAG != 0 {
					write_str(buffer, msg.author.name)
				}
			}
		}

		write_u16(buffer, u16(len(dyn_user_ids)), addr)
		user_ids = dyn_user_ids[:]
	}

	write_u16(buffer, u16(len(file.messages)))

	fmt.println("getting messages...")
	for msg in file.messages {
		write_u64_str(buffer, msg.id)

		msg_flags: u8
		if flags & DM_FLAG != 0 {
			if msg.author.id == file.messages[0].author.id {
				msg_flags |= RECV_FLAG
			}
		} else {
			user_id_index, ok := slice.linear_search(user_ids, msg.author.id)
			if !ok {
				panic("could not find user id index! (should not happend!!!)")
			}
			write_u16(buffer, u16(user_id_index))
		}
		if msg.pinned {
			msg_flags |= PINNED_FLAG
		}

		basic_att: [dynamic]string
		smart_att: [dynamic]SmartAttachment
		for att in msg.attachments {
			_, host, path, queries, _ := net.split_url(att.url)
			if host == "cdn.discordapp.com" && strings.has_prefix(path, "/attachments/") {
				// smart
				split_path := strings.split(path, "/")
				ch_id := split_path[2]
				id := split_path[3]
				name := split_path[4]
				exp := queries["ex"]
				iss := queries["is"]
				sign := queries["hm"]
				append(&smart_att, SmartAttachment{ch_id, id, name, exp, iss, sign})
			} else {
				// basic
				fmt.println("basic att!")
				append(&basic_att, att.url)
			}
		}
		write_u8(buffer, u8(len(basic_att)))
		for url in basic_att {
			write_str(buffer, url)
		}
		write_u8(buffer, u8(len(smart_att)))
		for att in smart_att {
			write_u64_str(buffer, att.channel_id)
			write_u64_str(buffer, att.id)
			write_str(buffer, att.name)
			write_u32_hex(buffer, att.expire)
			write_u32_hex(buffer, att.issue)
			write_u64_hex(buffer, att.signature[:16])
			write_u64_hex(buffer, att.signature[16:32])
			write_u64_hex(buffer, att.signature[32:48])
			write_u64_hex(buffer, att.signature[48:])
		}

		write_u8(buffer, msg_flags)
		write_str(buffer, msg.content)
	}

	fok := os.write_entire_file(os.args[2], bytes.buffer_to_bytes(buffer))
	if !fok {
		panic("could not write output data")
	}
	fmt.println("wrote", bytes.buffer_length(buffer), "bytes!")
}

write_u64 :: proc(buffer: ^bytes.Buffer, v: u64) {
	t64: [size_of(u64)]byte
	endian.put_u64(t64[:], .Big, v)
	bytes.buffer_write(buffer, t64[:])
}

write_u64_str :: proc(buffer: ^bytes.Buffer, str: string) {
	ch_id, _ := strconv.parse_u64(str)
	write_u64(buffer, ch_id)
}

write_u64_hex :: proc(buffer: ^bytes.Buffer, str: string) {
	ch_id, _ := strconv.parse_u64(str, 16)
	write_u64(buffer, ch_id)
}

write_u32_hex :: proc(buffer: ^bytes.Buffer, str: string) {
	ch_id, _ := strconv.parse_u64(str, 16)
	write_u32(buffer, u32(ch_id))
}

write_u32 :: proc(buffer: ^bytes.Buffer, v: u32) {
	t32: [size_of(u32)]byte
	endian.put_u32(t32[:], .Big, v)
	bytes.buffer_write(buffer, t32[:])
}

write_u16 :: proc(buffer: ^bytes.Buffer, v: u16, addr: Maybe(int) = nil) {
	t16: [size_of(u16)]byte
	endian.put_u16(t16[:], .Big, v)

	if addr, ok := addr.?; ok {
		inject_at(&buffer.buf, addr, ..t16[:])
	} else {
		bytes.buffer_write(buffer, t16[:])
	}
}

write_u8 :: proc(buffer: ^bytes.Buffer, v: u8) {
	bytes.buffer_write(buffer, []u8{v})
}

write_str :: proc(buffer: ^bytes.Buffer, str: string) {
	write_u16(buffer, u16(len(str)))
	bytes.buffer_write(buffer, transmute([]u8)str)
}
