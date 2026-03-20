#!/usr/bin/env tclsh
#
# Multi-Client TCP Chat Server
# Demonstrates Tcl's event-driven socket programming.
#
# Usage:
#   Server: tclsh chat_server.tcl [port]
#   Client: telnet localhost 9000
#           (or) nc localhost 9000

namespace eval chat {
    variable clients      ;# array: channel -> client info dict
    variable server_sock
    variable port 9000
    variable motd "Welcome to the Tcl Chat Server!"

    array set clients {}

    proc start {{p 9000}} {
        variable server_sock
        variable port
        set port $p

        set server_sock [socket -server [namespace code accept] $port]
        puts "╔════════════════════════════════════════╗"
        puts "║   Tcl Chat Server                      ║"
        puts "║   Listening on port $port               ║"
        puts "║   Press Ctrl+C to stop                  ║"
        puts "╚════════════════════════════════════════╝"
        log "Server started on port $port"
    }

    proc accept {chan addr port} {
        variable clients
        variable motd

        fconfigure $chan -buffering line -blocking 0 -translation auto

        set clients($chan) [dict create \
            addr $addr \
            port $port \
            nick "" \
            joined [clock seconds]]

        puts $chan $motd
        puts $chan "Enter your nickname: "

        fileevent $chan readable [namespace code [list handle_input $chan]]
        log "Connection from $addr:$port (channel $chan)"
    }

    proc handle_input {chan} {
        variable clients

        if {[catch {gets $chan line} count] || $count < 0} {
            if {[eof $chan]} {
                disconnect $chan
            }
            return
        }

        set line [string trim $line]
        if {$line eq ""} return

        set info $clients($chan)
        set nick [dict get $info nick]

        if {$nick eq ""} {
            set_nickname $chan $line
            return
        }

        if {[string index $line 0] eq "/"} {
            handle_command $chan $line
        } else {
            broadcast "$nick: $line" $chan
        }
    }

    proc set_nickname {chan name} {
        variable clients

        set name [string trim $name]
        if {$name eq "" || [string length $name] > 20} {
            puts $chan "Nickname must be 1-20 characters. Try again:"
            return
        }

        if {[regexp {[^a-zA-Z0-9_-]} $name]} {
            puts $chan "Nickname can only contain letters, numbers, _ and -. Try again:"
            return
        }

        foreach {c info} [array get clients] {
            if {[dict get $info nick] eq $name} {
                puts $chan "Nickname '$name' is taken. Try another:"
                return
            }
        }

        dict set clients($chan) nick $name
        puts $chan "Welcome, $name! Type /help for commands.\n"
        broadcast "*** $name has joined the chat ***" $chan
        log "User '$name' joined from [dict get $clients($chan) addr]"
    }

    proc handle_command {chan line} {
        variable clients

        set parts [split $line " "]
        set cmd [string tolower [lindex $parts 0]]
        set args [lrange $parts 1 end]

        switch $cmd {
            /help {
                puts $chan {
Available commands:
  /help           Show this help
  /nick <name>    Change nickname
  /who            List online users
  /msg <user> <text>  Private message
  /me <action>    Perform an action
  /time           Show server time
  /uptime         Show your session duration
  /quit           Disconnect
                }
            }
            /who {
                puts $chan "\nOnline users:"
                foreach {c info} [array get clients] {
                    set n [dict get $info nick]
                    if {$n ne ""} {
                        set duration [format_duration [expr {[clock seconds] - [dict get $info joined]}]]
                        puts $chan [format "  %-20s (connected %s)" $n $duration]
                    }
                }
                puts $chan ""
            }
            /nick {
                if {[llength $args] < 1} {
                    puts $chan "Usage: /nick <new_name>"
                    return
                }
                set old_nick [dict get $clients($chan) nick]
                set new_nick [lindex $args 0]
                dict set clients($chan) nick ""
                set_nickname $chan $new_nick
                if {[dict get $clients($chan) nick] ne ""} {
                    broadcast "*** $old_nick is now known as $new_nick ***" $chan
                } else {
                    dict set clients($chan) nick $old_nick
                }
            }
            /msg {
                if {[llength $args] < 2} {
                    puts $chan "Usage: /msg <user> <message>"
                    return
                }
                set target [lindex $args 0]
                set msg [join [lrange $args 1 end] " "]
                set sender [dict get $clients($chan) nick]
                set found 0
                foreach {c info} [array get clients] {
                    if {[dict get $info nick] eq $target} {
                        puts $c "\[PM from $sender\] $msg"
                        puts $chan "\[PM to $target\] $msg"
                        set found 1
                        break
                    }
                }
                if {!$found} {
                    puts $chan "User '$target' not found."
                }
            }
            /me {
                set action [join $args " "]
                set nick [dict get $clients($chan) nick]
                broadcast "* $nick $action"
            }
            /time {
                puts $chan "Server time: [clock format [clock seconds]]"
            }
            /uptime {
                set joined [dict get $clients($chan) joined]
                set duration [format_duration [expr {[clock seconds] - $joined}]]
                puts $chan "You have been connected for $duration"
            }
            /quit {
                puts $chan "Goodbye!"
                disconnect $chan
            }
            default {
                puts $chan "Unknown command: $cmd (type /help for commands)"
            }
        }
    }

    proc broadcast {message {exclude ""}} {
        variable clients
        foreach {chan info} [array get clients] {
            if {$chan ne $exclude && [dict get $info nick] ne ""} {
                catch { puts $chan $message }
            }
        }
        log $message
    }

    proc disconnect {chan} {
        variable clients
        set nick ""
        if {[info exists clients($chan)]} {
            set nick [dict get $clients($chan) nick]
            unset clients($chan)
        }
        catch { close $chan }
        if {$nick ne ""} {
            broadcast "*** $nick has left the chat ***"
            log "User '$nick' disconnected"
        }
    }

    proc format_duration {seconds} {
        set hours [expr {$seconds / 3600}]
        set mins [expr {($seconds % 3600) / 60}]
        set secs [expr {$seconds % 60}]
        if {$hours > 0} {
            return "${hours}h ${mins}m"
        } elseif {$mins > 0} {
            return "${mins}m ${secs}s"
        } else {
            return "${secs}s"
        }
    }

    proc log {message} {
        set ts [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
        puts "\[$ts\] $message"
    }

    proc stop {} {
        variable server_sock
        variable clients
        broadcast "*** Server is shutting down ***"
        foreach {chan info} [array get clients] {
            catch { close $chan }
        }
        catch { close $server_sock }
        log "Server stopped"
    }
}

if {[info script] eq $argv0} {
    set port [expr {[llength $argv] > 0 ? [lindex $argv 0] : 9000}]
    chat::start $port
    vwait forever
}
