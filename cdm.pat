#pragma endian big

bitfield MessageFlags {
    recv : 1;
    pinned : 1;
};

struct BasicAttachment {
    u16 url_length;
    char url[url_length];
};

struct SmartAttachment {
    u64 channel_id;
    u64 id;
    u16 name_length;
    char name[name_length];
    u32 expire;
    u32 issue;
    u64 signature;
};

struct Message {
    u64 id;

    if (file_flags.dms == 0) {
        u16 user_id_index;
    }
    
    u8 basic_attachment_count;
    BasicAttachment basic_attachments[basic_attachment_count];
    
    u8 smart_attachment_count;
    SmartAttachment smart_attachments[smart_attachment_count];
    
    MessageFlags flags;
    u16 content_length;
    char content[content_length];
};

bitfield FileFlags {
    dms : 1;
};

FileFlags file_flags;

struct File {
    FileFlags flags;
    file_flags = flags;
    
    u64 channel_id;
    
    if (flags.dms == 1) {
        u64 user_ids[2];
    } else {
        u64 guild_id;
        u16 user_id_count;
        u64 user_ids[user_id_count];
    }
    
    u16 message_count;
    Message messages[message_count];
};

File file @ 0;
