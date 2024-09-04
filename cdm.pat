#pragma endian big

struct Array<T, L> {
	L length;
	T elements[length];
};

struct String {
	Array<char, u16>;
};

bitfield MessageFlags {
	recv: 1;
	pinned: 1;
};

struct SmartAttachment {
	u64 channel_id;
	u64 id;
	String name;
	u32 expire;
	u32 issue;
	u64 signature[4];
};

struct Message {
	u64 id;

	if (file_flags.dms == 0) {
		u16 user_id_index;
	}
	
	Array<String, u8> basic_attachments;
	Array<SmartAttachment, u8> smart_attachments;
	
	MessageFlags flags;
	String content;
};

bitfield FileFlags {
	dms: 1;
	usernames: 1;
};

FileFlags file_flags;

struct User {
	u64 id;
	
	if (file_flags.usernames == 1) {
		String username;
	}
};

struct File {
	FileFlags flags;
	file_flags = flags;
	
	u64 channel_id;
	
	if (flags.dms == 1) {
		User user_ids[2];
	} else {
		u64 guild_id;
		Array<User, u16> users;
	}
	
	Array<Message, u32> messages;
};

File file @ 0;
