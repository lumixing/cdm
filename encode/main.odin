package encode

import "core:bytes"
import "core:encoding/endian"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strconv"

main :: proc() {
	data, ok := os.read_entire_file("samples/getimis.json")
	if !ok {
		panic("could not read input file")
	}

	v, err := json.parse(data)
	if err != nil {
		panic("could not parse data")
	}

	buffer := new(bytes.Buffer)
	t64: [size_of(u64)]byte
	t32: [size_of(u32)]byte
	t16: [size_of(u16)]byte

	ch_id, _ := strconv.parse_u64(v.(json.Object)["channel"].(json.Object)["id"].(json.String))
	endian.put_u64(t64[:], .Big, ch_id)
	bytes.buffer_write(buffer, t64[:])

	messages := v.(json.Object)["messages"].(json.Array)

	endian.put_u16(t16[:], .Big, u16(len(messages)))
	bytes.buffer_write(buffer, t16[:])

	for msg in messages {
		msg := msg.(json.Object)

		id, _ := strconv.parse_u64(msg["id"].(json.String))
		endian.put_u64(t64[:], .Big, id)
		bytes.buffer_write(buffer, t64[:])

		content := msg["content"].(json.String)
		endian.put_u16(t16[:], .Big, u16(len(content)))
		bytes.buffer_write(buffer, t16[:])
		bytes.buffer_write(buffer, transmute([]u8)content)
	}

	fok := os.write_entire_file("out.cdm", bytes.buffer_to_bytes(buffer))
	if !fok {
		panic("could not write output data")
	}
	fmt.println("wrote", bytes.buffer_length(buffer), "bytes!")
}
