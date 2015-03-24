;;;; Copyright (c) Frank James 2015 <frank.a.james@gmail.com>
;;;; This code is licensed under the MIT license.


(defpackage #:frpc
  (:use #:cl)
  (:export #:use-rpc-program
	   #:use-rpc-host
	   #:defrpc
	   #:defhandler
	   #:find-handler

	   ;; type definitions
	   #:defxtype
	   #:defxunion
	   #:defxenum
	   #:defxstruct	   
	   #:defxtype*
	   #:read-xtype
	   #:write-xtype
	   #:xtype-reader
	   #:xtype-writer

	   ;; enums/unions
	   #:enum
	   #:enump
	   #:make-xunion
	   #:xunion-tag
	   #:xunion-val

	   ;; functions for type definitions
	   #:defreader
	   #:defwriter
	   #:with-reader
	   #:with-writer

	   ;; serializing to/from buffer 
	   #:pack
	   #:unpack

	   ;; client
	   #:rpc-connect
	   #:rpc-close
	   #:with-rpc-connection
	   #:call-rpc-server
	   #:call-rpc
	   #:*rpc-host*
	   #:*rpc-port*
	   #:*rpc-msgid*
	   #:make-msgid

	   ;; server
	   #:make-rpc-server
	   #:start-rpc-server
	   #:run-rpc-server
	   #:stop-rpc-server
	   
	   ;; specials that are binded in the context of a handler
	   #:*rpc-remote-host*
	   #:*rpc-remote-port*
	   #:*rpc-remote-protocol*
	   #:*rpc-remote-auth*

	   ;; errors
	   #:rpc-error
	   #:rpc-accept-error
	   #:rpc-prog-mismatch-error
	   #:rpc-timeout-error
	   #:rpc-auth-error
	   #:rpc-mismatch-error

       ;; structures
       #:make-opaque-auth
       #:opaque-auth-flavour
       #:opaque-auth-data

	   ))

