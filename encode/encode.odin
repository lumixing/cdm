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

ENDIAN: endian.Byte_Order : .Little

FileFlag :: enum {
	Usernames,
	IgnoreQueries,
	// internal
	DirectMessage,
}
FileFlags :: bit_set[FileFlag]

MessageFlag :: enum {
	// internal
	Receiver,
	Pinned,
}
MessageFlags :: bit_set[MessageFlag]

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

	flags := FileFlags{.IgnoreQueries}

	user_ids: []string

	if file.guild.id == "0" {
		flags += {.DirectMessage}
	}

	write_u8(buffer, transmute(u8)flags)
	write_u64_str(buffer, file.channel.id)

	fmt.println("getting user ids")
	if .DirectMessage in flags {
		recv := file.messages[0].author.id
		write_u64_str(buffer, recv)
		if .Usernames in flags {
			write_str(buffer, file.messages[0].author.name)
		}

		for msg in file.messages {
			if msg.author.id != recv {
				write_u64_str(buffer, msg.author.id)
				if .Usernames in flags {
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
				if .Usernames in flags {
					write_str(buffer, msg.author.name)
				}
			}
		}

		write_u16(buffer, u16(len(dyn_user_ids)), addr)
		user_ids = dyn_user_ids[:]
	}

	write_u32(buffer, u32(len(file.messages)))

	fmt.println("getting messages...")
	for msg in file.messages {
		write_u64_str(buffer, msg.id)
		addr := bytes.buffer_length(buffer)

		msg_flags: MessageFlags
		if .DirectMessage in flags {
			if msg.author.id == file.messages[0].author.id {
				msg_flags += {.Receiver}
			}
		} else {
			user_id_index, ok := slice.linear_search(user_ids, msg.author.id)
			if !ok {
				panic("could not find user id index! (should not happend!!!)")
			}
			write_u16(buffer, u16(user_id_index))
		}
		if msg.pinned {
			msg_flags += {.Pinned}
		}

		write_u8(buffer, transmute(u8)msg_flags, addr)

		addr = bytes.buffer_length(buffer)
		basic_att: int
		smart_att: int
		for att in msg.attachments {
			_, host, path, queries, _ := net.split_url(att.url)
			if host == "cdn.discordapp.com" && strings.has_prefix(path, "/attachments/") {
				// smart
				split_path := strings.split(path, "/")
				sign := queries["hm"]
				write_u64_str(buffer, split_path[2])
				write_u64_str(buffer, split_path[3])
				write_str(buffer, split_path[4])
				if .IgnoreQueries not_in flags {
					write_u32_hex(buffer, queries["ex"])
					write_u32_hex(buffer, queries["is"])
					write_u64_hex(buffer, sign[:16])
					write_u64_hex(buffer, sign[16:32])
					write_u64_hex(buffer, sign[32:48])
					write_u64_hex(buffer, sign[48:])
				}
				smart_att += 1
			} else {
				// basic
				basic_att += 1
				write_str(buffer, att.url)
			}
		}
		// reverse is important!!
		write_u8(buffer, u8(smart_att), addr)
		write_u8(buffer, u8(basic_att), addr)

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
	endian.put_u64(t64[:], ENDIAN, v)
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
	endian.put_u32(t32[:], ENDIAN, v)
	bytes.buffer_write(buffer, t32[:])
}

write_u16 :: proc(buffer: ^bytes.Buffer, v: u16, addr: Maybe(int) = nil) {
	t16: [size_of(u16)]byte
	endian.put_u16(t16[:], ENDIAN, v)

	if addr, ok := addr.?; ok {
		inject_at(&buffer.buf, addr, ..t16[:])
	} else {
		bytes.buffer_write(buffer, t16[:])
	}
}

write_u8 :: proc(buffer: ^bytes.Buffer, v: u8, addr: Maybe(int) = nil) {
	if addr, ok := addr.?; ok {
		inject_at(&buffer.buf, addr, v)
	} else {
		bytes.buffer_write(buffer, []u8{v})
	}
}

write_str :: proc(buffer: ^bytes.Buffer, str: string) {
	write_u16(buffer, u16(len(str)))
	bytes.buffer_write(buffer, transmute([]u8)str)
}
