# FRPC
Frank's XDR/RPC library is an implementation of the ONC-RPC ("SunRPC") protocol. The library is composed of two
components: implementing the eXtensible Data Representation (XDR), which is the method of serializing the messages, 
and the Remote Procedure Call (RPC) system itself, which uses XDR to exchange messages.

1. Defining RPC interfaces
----------------------------

RPC interfaces are given a unique integer called a program number. Each program may have multiple
versions of its interface, with each version having a different set of functions/arguments. Each procedure
in the interface is also given a unique number. Together these 3 integers define the procedure identifier.

In FRPC, both clients and servers must define the interface. This supplies argument and result types.
Servers must additionally implement handlers for each procedure they wish to support.

For instance, a client should write:
```
(defrpc call-hello 0 :string :string)
(defrpc call-goodbye 1 :uint32 :string)
```

This defines 2 Lisp functions to call out to an RPC server to execute the procedures.

A servers should additionally write
```
(defrpc call-hello 0 :string :string)
(defhandler handle-hello (msg 0)
  (format nil "Hello, ~A!" msg))

(defrpc call-goodbye 1 :uint32 :string)
(defhandler handle-goodbye (u 0)
  (format nil "Goodbye ~A!" u))))
```

The types provided to DEFRPC can be a generalized type specifier, as described
below in section 4.5.

2. Client
----------

The DEFRPC macro defines a wrapper around the underlying CALL-RPC function, with various 
arguments supplied. Thus, with the example above, the client will be able to call a remote 
RPC server using, e.g., 

```
(call-hello #(192 168 0 2) "hello" :port 8000)
```

3. RPC Server
----------------

Singly-threaded TCP and UDP servers are currently implemented.

3.1 TCP server
---------------

At present only a single (singly-threaded) server may run at any one time. 
See examples for usage.

```
(defvar *server* (make-rpc-server))
(start-rpc-server *server* :port 8000)
(stop-rpc-server *server*)
```

3.2 UDP server
----------------

UDP servers work as above, except are implemented with UDP-RPC-SERVER instances.

```
(defvar *server* (make-udp-rpc-server))
(start-rpc-server *server* :port 8000)
(stop-rpc-server *server*)
```

4. XDR serializer
----------------

The XDR serializer is largely decoupled from the rpc implementation. This means it 
could be used for other purposes as a generalised binary serialization system for any purpose.

4.1 Primitive types
----------------------

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

Use READ-XTYPE and WRITE-XTYPE to reader/write an instance of 
the type to/from a stream.

Use PACK/UNPACK to store/extract instances from buffers rather than streams.

4.2 enums
------------

Define enum types using
```
(defxenum enum-type
  (symbol integer)
  ...)
```

Lookup a corresponding integer or symbol using
```
(enum enum-type val)
```
where val is either an integer or a symbol.

4.3 unions
-----------

Define union types using
```
(defxunion union-type (enum-type)
  ((enum-symbol type-name)
  ...))
```

4.4 structures
----------------

Define structures using

```
(defxstruct struct-name ()
  ((slot-name type-name &optional initial-value)
  ...))
```

4.5 Generalized types
------------------------

```
(defxtype* name ()
  form)
```

Where the FORM is:
* a symbol, naming another xtype
* (:list &rest forms)
* (:alist &rest (tag form))
* (:plist &rest (tag form))
* (:struct struct-name &rest (slot-name form))
* (:union enum-name &rest (enum-keys form))
* (:array form length)
* (:varray form &optional length)
* (:varray* form &optional length)

These rules can be applied recursively. 

You may define local readers and writers using WITH-READER and WITH-WRITER macros.

5. Examples
-------------

I have typed in some simple example programs, see e.g. examples/hello.lisp.
Have a look at the portmappter, pmapper.lisp and also FRPC's sister project, 
NEFARIOUS, an attempt at an NFS implementation.

6. License
------------

Released under the terms of the MIT license.

Frank James 
Febuary 2015.







