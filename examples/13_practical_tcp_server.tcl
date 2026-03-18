#!/usr/bin/env tclsh
# =============================================================================
# Example 13: Practical - TCP Echo Server and Client
# A simple event-driven TCP server that echoes messages back to clients.
# Run this script to start the server, then connect with: telnet localhost 9876
# =============================================================================

# NOTE: This example demonstrates the concepts. To actually run it,
# execute: tclsh 13_practical_tcp_server.tcl
# Then in another terminal: echo "Hello" | nc localhost 9876

puts "=== TCP Echo Server Example ===\n"

namespace eval EchoServer {
    variable client_count 0
    variable server_socket ""

    proc start {port} {
        variable server_socket
        set server_socket [socket -server [namespace code accept] $port]
        puts "Echo server listening on port $port"
        puts "Connect with: echo 'Hello' | nc localhost $port"
        puts "Press Ctrl+C to stop\n"
    }

    proc accept {chan addr port} {
        variable client_count
        incr client_count

        puts "Client #$client_count connected from $addr:$port"
        fconfigure $chan -buffering line -translation auto
        fileevent $chan readable [namespace code [list handle $chan $client_count $addr]]
    }

    proc handle {chan id addr} {
        if {[catch {gets $chan line} count] || [eof $chan]} {
            puts "Client #$id ($addr) disconnected"
            catch {close $chan}
            return
        }

        if {$count < 0} return

        set timestamp [clock format [clock seconds] -format "%H:%M:%S"]
        puts "\[$timestamp\] Client #$id: $line"

        if {[string tolower [string trim $line]] eq "quit"} {
            puts $chan "Goodbye!"
            puts "Client #$id requested disconnect"
            close $chan
            return
        }

        puts $chan "Echo: $line"
    }

    proc stop {} {
        variable server_socket
        if {$server_socket ne ""} {
            close $server_socket
            set server_socket ""
            puts "Server stopped"
        }
    }
}

# Demonstrate the server structure without blocking
puts "Server code is defined in namespace EchoServer."
puts "Key procedures:"
puts "  EchoServer::start port  - Start listening"
puts "  EchoServer::accept      - Handle new connections"
puts "  EchoServer::handle      - Process client messages"
puts "  EchoServer::stop        - Stop the server"
puts ""
puts "To run interactively, uncomment the lines below:\n"
puts "  # EchoServer::start 9876"
puts "  # vwait forever"
puts ""

# --- Also demonstrate a simple client ---
puts "--- TCP Client Example ---\n"

namespace eval EchoClient {
    proc connect {host port} {
        set chan [socket $host $port]
        fconfigure $chan -buffering line
        return $chan
    }

    proc send {chan message} {
        puts $chan $message
        flush $chan
        gets $chan response
        return $response
    }

    proc disconnect {chan} {
        catch {close $chan}
    }
}

puts "Client code is defined in namespace EchoClient."
puts "Usage:"
puts "  set conn \[EchoClient::connect localhost 9876\]"
puts "  set reply \[EchoClient::send \$conn \"Hello\"\]"
puts "  EchoClient::disconnect \$conn"

# --- Self-test: start server, connect as client, exchange messages ---
puts "\n--- Self-Test (loopback) ---"

set test_port [expr {30000 + [pid] % 10000}]

try {
    EchoServer::start $test_port

    update
    set client [socket "localhost" $test_port]
    fconfigure $client -buffering line
    update

    foreach msg {"Hello, Server!" "TCL is great!" "Testing 123"} {
        puts $client $msg
        flush $client
        update
        gets $client reply
        puts "  Sent: '$msg' -> Got: '$reply'"
    }

    close $client
    update
    EchoServer::stop

    puts "\n  Self-test passed!"
} on error {msg} {
    puts "  Self-test error: $msg"
    catch {EchoServer::stop}
}

puts "\nDone."
