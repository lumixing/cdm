package encode

import "core:bytes"
import "core:encoding/endian"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strconv"

DM_FLAG: u8 : 0b1000_0000
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
	id:      string,
	content: string,
	author:  struct {
		id: string,
	},
	pinned:  bool `json:"isPinned"`,
}

main :: proc() {
	data, ok := os.read_entire_file("samples/getimis.json")
	if !ok {
		panic("could not read input file")
	}

	file: Data
	json.unmarshal(data, &file)
	buffer := new(bytes.Buffer)

	flags: u8

	if file.guild.id == "0" {
		flags |= DM_FLAG
	}

	write_u8(buffer, flags)
	write_u64_str(buffer, file.channel.id)

	if flags & DM_FLAG != 0 {
		recv := file.messages[0].author.id
		send: string
		for msg in file.messages {
			if msg.author.id != recv {
				send = msg.author.id
				break
			}
		}
		if send == "" {
			panic("could not find sender id!")
		}

		write_u64_str(buffer, recv)
		write_u64_str(buffer, send)
	}

	write_u16(buffer, u16(len(file.messages)))

	for msg in file.messages {
		write_u64_str(buffer, msg.id)

		msg_flags: u8
		if flags & DM_FLAG != 0 {
			if msg.author.id == file.messages[0].author.id {
				msg_flags |= RECV_FLAG
			}
		}
		if msg.pinned {
			msg_flags |= PINNED_FLAG
		}

		write_u8(buffer, msg_flags)
		write_u16(buffer, u16(len(msg.content)))
		bytes.buffer_write(buffer, transmute([]u8)msg.content)
	}

	fok := os.write_entire_file("out/out.cdm", bytes.buffer_to_bytes(buffer))
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

write_u16 :: proc(buffer: ^bytes.Buffer, v: u16) {
	t16: [size_of(u16)]byte
	endian.put_u16(t16[:], .Big, v)
	bytes.buffer_write(buffer, t16[:])
}

write_u8 :: proc(buffer: ^bytes.Buffer, v: u8) {
	bytes.buffer_write(buffer, []u8{v})
}
