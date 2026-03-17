#!/usr/bin/perl
#
# Todo App — A command-line to-do list manager with file persistence.
# Demonstrates file I/O, data structures, user input, and text formatting.
#
# Usage:
#   perl todo_app.pl                  — interactive mode
#   perl todo_app.pl add "Buy milk"   — add via command line
#   perl todo_app.pl list             — show all todos
#   perl todo_app.pl done 1           — mark #1 as complete
#   perl todo_app.pl remove 1         — remove #1
#
use strict;
use warnings;
use feature 'say';

my $TODO_FILE = "/tmp/perl_todos.txt";

sub load_todos {
    my @todos;
    return @todos unless -f $TODO_FILE;

    open(my $fh, '<', $TODO_FILE) or die "Cannot read $TODO_FILE: $!";
    while (my $line = <$fh>) {
        chomp $line;
        next unless $line =~ /\S/;
        my ($status, $created, $text) = split /\|/, $line, 3;
        push @todos, {
            text    => $text,
            done    => ($status eq 'DONE'),
            created => $created,
        };
    }
    close($fh);
    return @todos;
}

sub save_todos {
    my @todos = @_;
    open(my $fh, '>', $TODO_FILE) or die "Cannot write $TODO_FILE: $!";
    for my $todo (@todos) {
        my $status = $todo->{done} ? 'DONE' : 'TODO';
        print $fh "$status|$todo->{created}|$todo->{text}\n";
    }
    close($fh);
}

sub display_todos {
    my @todos = @_;

    if (!@todos) {
        say "  No todos yet. Add one with 'add <task>'";
        return;
    }

    my $pending = grep { !$_->{done} } @todos;
    my $completed = grep { $_->{done} } @todos;

    printf "\n  %-4s %-6s %-40s %s\n", "#", "Status", "Task", "Created";
    printf "  %s\n", "-" x 65;

    for my $i (0..$#todos) {
        my $t = $todos[$i];
        my $mark = $t->{done} ? "[x]" : "[ ]";
        my $text = $t->{done} ? strike($t->{text}) : $t->{text};
        printf "  %-4d %-6s %-40s %s\n", $i + 1, $mark, $text, $t->{created};
    }

    say "";
    say "  Summary: $pending pending, $completed completed, " . scalar @todos . " total";
}

sub strike {
    my ($text) = @_;
    return "~$text~";
}

sub add_todo {
    my ($text, @todos) = @_;
    my ($sec, $min, $hour, $day, $mon, $year) = localtime;
    my $created = sprintf "%04d-%02d-%02d %02d:%02d",
                          $year + 1900, $mon + 1, $day, $hour, $min;

    push @todos, {
        text    => $text,
        done    => 0,
        created => $created,
    };
    save_todos(@todos);
    say "  Added: '$text'";
    return @todos;
}

sub mark_done {
    my ($index, @todos) = @_;
    if ($index < 1 || $index > scalar @todos) {
        say "  Invalid todo number: $index";
        return @todos;
    }
    $todos[$index - 1]{done} = 1;
    save_todos(@todos);
    say "  Completed: '$todos[$index - 1]{text}'";
    return @todos;
}

sub remove_todo {
    my ($index, @todos) = @_;
    if ($index < 1 || $index > scalar @todos) {
        say "  Invalid todo number: $index";
        return @todos;
    }
    my $removed = splice(@todos, $index - 1, 1);
    save_todos(@todos);
    say "  Removed: '$removed->{text}'";
    return @todos;
}

sub show_help {
    say <<'HELP';

  Commands:
    add <task>     Add a new todo item
    list           Show all todos
    done <n>       Mark todo #n as complete
    remove <n>     Remove todo #n
    clear          Remove all completed todos
    help           Show this help message
    quit           Exit the program

HELP
}

# --- Main ---

my @todos = load_todos();

# CLI mode: handle arguments directly
if (@ARGV) {
    my $cmd = lc(shift @ARGV);
    if ($cmd eq 'add' && @ARGV) {
        @todos = add_todo(join(" ", @ARGV), @todos);
    } elsif ($cmd eq 'list') {
        display_todos(@todos);
    } elsif ($cmd eq 'done' && @ARGV) {
        @todos = mark_done($ARGV[0], @todos);
    } elsif ($cmd eq 'remove' && @ARGV) {
        @todos = remove_todo($ARGV[0], @todos);
    } else {
        say "Unknown command. Use: add|list|done|remove";
    }
    exit;
}

# Interactive mode
say "=== TODO APP ===";
say "Type 'help' for available commands.\n";

display_todos(@todos);

while (1) {
    print "\ntodo> ";
    my $input = <STDIN>;
    last unless defined $input;
    chomp $input;
    next unless $input =~ /\S/;

    my ($cmd, @args) = split /\s+/, $input;
    $cmd = lc($cmd);

    if ($cmd eq 'quit' || $cmd eq 'exit' || $cmd eq 'q') {
        say "Goodbye!";
        last;
    } elsif ($cmd eq 'add' && @args) {
        @todos = add_todo(join(" ", @args), @todos);
    } elsif ($cmd eq 'list' || $cmd eq 'ls') {
        display_todos(@todos);
    } elsif ($cmd eq 'done' && @args) {
        @todos = mark_done($args[0], @todos);
    } elsif ($cmd eq 'remove' || $cmd eq 'rm') {
        if (@args) {
            @todos = remove_todo($args[0], @todos);
        } else {
            say "  Usage: remove <number>";
        }
    } elsif ($cmd eq 'clear') {
        @todos = grep { !$_->{done} } @todos;
        save_todos(@todos);
        say "  Cleared completed todos.";
    } elsif ($cmd eq 'help' || $cmd eq '?') {
        show_help();
    } else {
        say "  Unknown command: '$cmd'. Type 'help' for options.";
    }
}
