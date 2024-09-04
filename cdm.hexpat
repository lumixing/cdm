#pragma endian little

struct Array<T, L> {
	L length;
	T elements[length];
};

struct String {
	Array<char, u16>;
};

bitfield MessageFlags {
	bool recv: 1;
	bool pinned: 1;
};

struct SmartAttachment {
	u64 channel_id;
	u64 id;
	String name;
	
	if (!file_flags.ignore_att_queries) {
		u32 expire;
		u32 issue;
		u64 signature[4];
	}
};

struct Message {
	u64 id;

	if (!file_flags.dms) {
		u16 user_id_index;
	}
	
	Array<String, u8> basic_attachments;
	Array<SmartAttachment, u8> smart_attachments;
	
	MessageFlags flags;
	String content;
};

bitfield FileFlags {
	bool dms: 1;
	bool usernames: 1;
	bool ignore_att_queries: 1;
};

FileFlags file_flags;

struct User {
	u64 id;
	
	if (file_flags.usernames) {
		String username;
	}
};

struct File {
	FileFlags flags;
	file_flags = flags;
	
	u64 channel_id;
	
	
	if (flags.dms) {
		User user_ids[2];
	} else {
		u64 guild_id;
		Array<User, u16> users;
	}
	
	Array<Message, u32> messages;
	
};

File file @ 0;
