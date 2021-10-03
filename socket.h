// A mockup of a possible socket API for the TI-84+ CE

// socket type def. sort of how fileioc works.
typedef ti_socket_t uint8_t;

enum _backends {
    BACKEND_USB,
    BACKEND_SERIAL_BRIDGE,
    BACKEND_IP_USB,
}

/*
    # Attempts to open a socket.
    *backend_spec = pointer to an array of backends to try, in order of preference.
        once a backend is successfully setup, that one will be used without trying the rest
        NULL to use the default
        
    @returns a ti_socket type
 */
ti_socket_t socket_open(const uint8_t *backend_spec);

/*
    # Attempts to connect socket to a remote host
    *remote = pointer to a remote address to connect to
    port = port number to connect to
    
    @returns true if success, false if failure
 */
bool socket_connect(ti_socket_t socket, const uint8_t* host, const uint16_t port);

/*
    # Attempts to write @len bytes at @data to @socket
    socket = an open ti socket
    *data = a pointer to data to send
    len = the size of the data to send
    
    @returns the number of bytes sent
 */
size_t socket_send(ti_socket_t socket, const uint8_t* data, size_t len);

/*
    # Attempts to read @len bytes from @socket to @buf.
    socket = an open ti socket
    *buf = a pointer to read bytes into
    len = number of bytes to try to read
    
    @returns len if successful, 0 if not enough bytes available or error
 */
size_t socket_get(ti_socket_t socket, uint8_t* buf, size_t len);
