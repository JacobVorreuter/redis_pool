-record(state, {
    ip = "127.0.0.1",
    port = 6379,
    pass,
    db = 0,
    socket,
    channel,
    callback
}).
