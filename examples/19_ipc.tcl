#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 19: Interprocess Communication
# =============================================================================

puts "=== Running External Commands with exec ==="
set hostname [exec hostname]
puts "Hostname: $hostname"

set date [exec date -u]
puts "UTC Date: $date"

puts "\n=== Capturing Command Output ==="
set kernel [exec uname -r]
puts "Kernel: $kernel"

set uptime_info [exec uptime]
puts "Uptime: $uptime_info"

puts "\n=== Piping Commands ==="
set txt_files [exec sh -c "ls /tmp 2>/dev/null | head -5 || true"]
puts "First 5 items in /tmp:"
foreach f [split $txt_files "\n"] {
    puts "  $f"
}

puts "\n=== Error Handling with exec ==="
if {[catch {exec ls /nonexistent_directory 2>@1} result]} {
    puts "Expected error: $result"
}

puts "\n=== Open Pipe for Reading ==="
set fd [open "|echo 'hello world' | tr a-z A-Z" r]
set result [read $fd]
close $fd
puts "Pipe result: [string trim $result]"

puts "\n=== Open Pipe for Writing ==="
set tmpfile "/tmp/tcl_ipc_sorted.txt"
set fd [open "|sort > $tmpfile" w]
foreach item {banana apple cherry date elderberry} {
    puts $fd $item
}
close $fd

set fd [open $tmpfile r]
puts "Sorted output:"
while {[gets $fd line] >= 0} {
    puts "  $line"
}
close $fd
file delete $tmpfile

puts "\n=== Two-Way Pipe ==="
set fd [open "|cat -n" r+]
puts $fd "first line"
puts $fd "second line"
puts $fd "third line"
flush $fd
close $fd write
set result [read $fd]
close $fd
puts "Numbered lines:"
puts $result

puts "=== Environment Variables ==="
puts "HOME: $::env(HOME)"
puts "PATH (first 80 chars): [string range $::env(PATH) 0 79]..."

if {[info exists ::env(USER)]} {
    puts "USER: $::env(USER)"
}

set ::env(MY_TCL_VAR) "Hello from Tcl"
set check [exec sh -c {echo $MY_TCL_VAR}]
puts "Env var in subprocess: $check"

puts "\n=== Process Substitution Pattern ==="
proc run_with_timeout {cmd timeout_ms} {
    set result ""
    set error_msg ""
    set done 0

    if {[catch {
        set fd [open "|$cmd" r]
        set result [read $fd]
        close $fd
    } err]} {
        set error_msg $err
    }

    if {$error_msg ne ""} {
        return [list error $error_msg]
    }
    return [list ok [string trim $result]]
}

lassign [run_with_timeout "echo 'Quick command'" 5000] status output
puts "Status: $status"
puts "Output: $output"

puts "\n=== Socket Concepts ==="
puts {
  TCP Server:
    proc accept {chan addr port} {
        puts "Connection from $addr:$port"
        gets $chan request
        puts $chan "Response: Hello!"
        close $chan
    }
    socket -server accept 9000
    vwait forever

  TCP Client:
    set sock [socket localhost 9000]
    puts $sock "Hello, server!"
    flush $sock
    gets $sock response
    puts "Server said: $response"
    close $sock

  UDP (via udp package):
    package require udp
    set sock [udp_open 9001]
    udp_conf $sock $host $port
    puts $sock "message"
}

puts "\n=== Practical: Simple Command Runner ==="
proc run_commands {commands} {
    set results [dict create]
    set idx 0
    foreach cmd $commands {
        incr idx
        puts "Running ($idx/[llength $commands]): $cmd"
        if {[catch {exec sh -c $cmd 2>@1} output]} {
            dict set results $cmd [dict create status "error" output $output]
            puts "  ERROR: $output"
        } else {
            dict set results $cmd [dict create status "ok" output $output]
            puts "  OK: [string range $output 0 79]"
        }
    }
    return $results
}

set cmds [list \
    "echo 'Hello from command 1'" \
    "date +%Y-%m-%d" \
    "uname -s" \
    "ls /nonexistent_path" \
]

puts "\n--- Running batch commands ---"
set results [run_commands $cmds]

puts "\n--- Summary ---"
set ok_count 0
set err_count 0
dict for {cmd info} $results {
    if {[dict get $info status] eq "ok"} {
        incr ok_count
    } else {
        incr err_count
    }
}
puts "Successful: $ok_count, Failed: $err_count"
