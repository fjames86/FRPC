# FRPC
FRPC is an implementation of the ONC-RPC ("SunRPC") protocol. 

The library is composed to two largely decoupled components: the eXtensible Data Representation (XDR) serializer,
which is used to define message structures and other on-wire formats, and the RPC framework itself.

See the related project [nefarious](https://github.com/fjames86/nefarious), which uses FRPC to implement an NFSv3 client and server.

## 1. Defining RPC interfaces

RPC interfaces are given a unique integer called a program number. Each program may have multiple
versions of its interface, with each version having a different set of functions/arguments. Each procedure
in the interface is also given a unique integer. Together these 3 integers define the procedure identifier.

In FRPC, both clients and servers must define the interface. This supplies argument and result types.
Servers must additionally implement handlers for each procedure they wish to support.

For instance, a client should write:
```
(defrpc call-hello 0 :string :string)
(defrpc call-goodbye 1 :uint32 :string)
```

This defines a Lisp function for each RPC proc to call out to an RPC server to execute the procedure, e.g.
```
CL-USER> (call-hello "Bob" :host "10.1.1.1" :port 1234 :protocol :udp)
"Hello, Bob!"
```

Servers should additionally implement handlers for the procedures they wish to support
```
(defun handle-hello (msg)
  (format nil "Hello, ~A!" msg))

(defrpc call-hello 0 :string :string
  (:handler #'handle-hello))

(defun handle-goodbye (u)
  (format nil "Goodbye ~A!" u))

(defrpc call-goodbye 1 :uint32 :string
  (:handler #'handle-goodbye))

```
The :HANDLER option specifies a function which accepts a single argument, which will be the value decoded according
to the rule defined for the arg-type by the DEFRPC form. The handler function should return a single value which will be 
passed to the result-type serializer defined by the DEFRPC form. Handlers should never signal errors because 
the RPC protocol does not have a generalized mechanism of reporting errors. Instead, your RPC interface will typically
define a set of error status codes which will be returned as a part of the handler's return value.

The types provided to DEFRPC can be a generalized type specifier, as described below in section 4.5.

## 2. Client


The DEFRPC macro defines a wrapper around the underlying CALL-RPC function, with default values provided 
for the argument writer, result reader, program, version and proc arguments. 

Thus, with the example above, the client will be able to call a remote RPC server using, e.g., 

```
(call-hello "hello" :host "10.1.1.1" :port 8000)
```

The default client function accepts a single mandatory argument, which must match the corresponding XDR type specifier.
However, typically the programmer would like to provide a better interface to hide the underlying implementation. 
For instance, consider a procedure which accepts and returns a structure of two strings:
```
(defxstruct my-arg ()
  (a :string)
  (b :string))
(defrpc call-my-proc 1 my-arg my-arg
  (:arg-transformer (a &key (b ""))
    (make-my-arg :a a :b b))
  (:transformer (res)
    (values (my-arg-a res) (my-arg-b res)))
  (:documentation "Accepts two strings A and B. Returns (values (string-upcase A) (string-upcase B))."))
```
The resulting client function can then be called:
```
CL-USER> (call-my-proc "Alice" :b "Bob" :host "10.1.1.1" :port 1234 :protocol :udp)
"ALICE"
"BOB"
```

The :ARG-TRANSFORMER option specifies how to transform the arguments to the function into arguments for 
the RPC call. You may use this to allow some of the arguments be passed in as keyword parameters. 
The :TRANSFORMER option specifies how to transform the result of the RPC call back to Lisp.
Documentation strings can be provided with the :DOCUMENTATION option.

### 2.1 CALL-RPC

The low-level client functionality is provided by CALL-RPC. This function is used by a client to 
send an RPC request to a remote server and blocks until a reply is received.

### 2.2 TCP connections

You can provide a connection to the functions defined by DEFRPC. This makes it more efficient to send multiple 
messages to a single server, without having to reconnect for each request.

Use RPC-CONNECT and RPC-CLOSE to establish and close a connection. The macro WITH-RPC-CONNECTION can be used to ensure the connection is closed on exit.

```
;; normal way to do it. establishes a connection and closes it at the end 
(pmap:call-dump "192.168.0.8" :protocol :tcp)

;; reuses a connection to the server 
(frpc:with-rpc-connection (c "192.168.0.8" 111) 
  (list (pmap:call-dump :connection c) 
        (pmap:call-dump :connection c)))
```

### 2.3 UDP 

Specifying :UDP as the protocol will send the message using the UDP transport instead of TCP (the default). If you care about the result, then specify a timeout in seconds to wait for the reply. If not reply is received an FRPC-TIMEOUT-ERROR will be raised, otherwise the function returns immediately with retult nil.

```
(pmap:call-null :host "192.168.0.1" :protocol :udp)
```

Users may also supply a connection argument for UDP so that they don't need to keep making new UDP sockets for each RPC.
```
(let ((sock (usocket:socket-connect host port :protocol :datagram)))
  (pmap:call-null :protocol :udp :connection sock)
  (pmap:call-dump :protocol :udp :connection sock)
  (usocket:socket-close sock))
```

### 2.4 UDP broadcast

You may send messages using UDP broadcast to find services on your local network.

```
(pmap:call-null :host "255.255.255.255" :protocol :broadcast)
```

Broadcast messages return a list of the responses received within the timeout -- no timeout error is raised if no replies are received. Each element in the list is a list of 3 items (host port result), where host and port identify where the response came from and result is the result of decoding the message that was received.

## 3. RPC Server

An RPC server runs from within a single thread and listens on a set of TCP and UDP ports. It my serve a subset of available RPC programs, by default serving all programs. Authentication handlers can be supplied to filter client requests.

```
;; make a server instance
(defvar *server* (make-rpc-server))

;; start the server in a new thread, it will listen for requests on TCP and UDP ports 8000
(start-rpc-server *server* :tcp-ports '(8000) :udp-ports '(8000))

;; stop the server thread
(stop-rpc-server *server*)
```

When the server accepts a TCP connection, it is added to a list of currently open connections. The server will select a connection to process using USOCKET:WAIT-FOR-INPUT. This allows the server to keep open multiple TCP connections without blocking other traffic. Note that the socket IO is still syncronous. Connections which are idle for TIMEOUT seconds (default 60 seconds) are closed by the FRPC server. 

## 4. XDR serializer

The XDR serializer is largely decoupled from the rpc implementation. This means it 
could be used for other purposes as a generalised binary serialization system.

### 4.1 Primitive types

The primitive types which come predefined are:
* :int32 :uint32 :int64 :uint64 :octet
* :string
* :boolean
* :real32 :real64
* :void

You may define new primitive types using:
```
(defxtype name ((:reader reader-name) (:writer writer-name))
  ((stream) body-reading-value-from-stream)
  ((stream obj) body-writing-obj-to-stream))
```
Only very rare circumstances should require doing this.

The optional parameters READER-NAME and WRITER-NAME are the function names
generated for the type's reader and writer. If not provided, %READ- and %WRITE- 
prepended with the type's name are used.

Use XTYPE-READER and XTYPE-WRITER to lookup the type's reader
and writer functions.

Use READ-XTYPE and WRITE-XTYPE to read/write an instance of 
the type to/from a stream.

Use PACK/UNPACK to store/extract instances from buffers rather than streams.

### 4.2 enums

Define enum types using
```
(defxenum enum-name
  (symbol integer)
  ...)
```

Lookup a corresponding integer or symbol using
```
(enum enum-type val)
```
where val is either an integer or a symbol.

### 4.3 unions

Define union types using
```
(defxunion union-type (enum-type)
  ((enum-symbol type-name)
  ...))
```

### 4.4 structures

Define structures using

```
(defxstruct struct-name ()
  (slot-name type-name &optional initial-value)
  ...)
```

### 4.5 Generalized types

```
(defxtype* name ()
  form)
```

Where the FORM is:
* a symbol, naming another xtype
* (:list &rest forms) 
* (:alist &rest (tag form))
* (:plist &rest key form)
* (:struct struct-name &rest (slot-name form))
* (:union enum-name &rest (enum-keys form))
* (:array form length) 
* (:varray form &optional length) 
* (:varray* form &optional length)

These rules can be applied recursively. 

You may define global readers/writers using DEFREADER and DEFWRITER. These macros generate DEFUN forms. 
The equivalent macros using FLET are WITH-READER and WITH-WRITER.

### 4.6 XDR examples

```
;; defstruct and define reader/writer for it 
(defxstruct foobar ((:reader read-foobar) (:writer write-foobar))
  (x :string)
  (y :uint32))

;; serialize the structure to a file 
(with-open-file (f "foobar.dat" :direction :output :if-exists :supersede :element-type '(unsigned-byte 8))
  (write-foobar f (make-foobar :x "hello" :y 123)))
;; deserialize the stucture from a file 
(with-open-file (f "foobar.dat" :direction :intput :element-type '(unsigned-byte 8))
  (read-foobar f))
```

## 5. Examples

I have typed in some simple example programs. 
For more serious usages, see port-mapper.lisp or Nefarious, an NFS implementation in Common Lisp.

## 6. Logging 

Debug logging is provided by [pounds](https://github.com/fjames86/pounds). By default this will create a 2MB log file
in your home directory named "frpc.log". You should change the path by modifying:

```
(setf frpc:*frpc-log-path* (merge-pathnames (user-homedir-pathname) "foo.log"))
```
The log is created on the first call to FRPC-LOG. 

For debugging and development you may follow the log to see output as it arrives:
```
(pounds.log:start-following *frpc-log*)

(pounds.log:stop-following)
```

Users may also write to this log if they wish, you should simply use a different tag.
```
(let ((tag (babel:string-to-octets "MYLG")))
  (defun my-log (lvl format-control &rest args)
    (unless *frpc-log*		  
      (frpc-log :info "Initialzing log"))
    (pounds.log:write-message *frpc-log* 
    			      lvl 		      
			      (apply #'format nil format-control args)
			      :tag tag)))
```

See the pounds documentation for more information on the logging system.

## 7. Notes

* I've not really put any effort into properly handling authentication, either for the client or the server.
* Default protocol is TCP, should this be changed to UDP? 
* At the moment, reading from TCP streams requires buffering the input to cope with reading multiple fragments. 
A fragmented-stream type could be defined to wrap the underlying socket stream so that we can avoid the buffering on reads.
You still need to buffer writes because you need to know how much you intend to write before you've written it.
* You can start listening on wildcard ports (by supplying 0 as a port number), but there is no way to find out what ports
were selected. This makes it impossible to inform the port mapper of where to direct traffic.
* Could make it easier to add more transports, e.g. using CL+SSL.
* UDP multicast?
* The XDR serializer is probably not as efficient as it could be.
* The UDP processing does a lot of consing. This needs to be improved because sending every UDP message
currently requires consing 64k as a receive buffer. Perhaps a pool of pre-allocated buffers we can cycle through 
would help.
* Could add a stream class that is roughly comparable to flexi-streams' binary vector-stream, except it writes 
to a pre-allocated buffer. That way we could reuse the statically allocated buffers we need to read responses from too.

## 8. License

Released under the terms of the MIT license.

Frank James 
Febuary 2015.

