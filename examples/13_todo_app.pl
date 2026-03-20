#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';
use File::Temp qw(tempfile);

# --- Practical Project: Command-Line TODO Manager ---
# Demonstrates file I/O, data structures, user interaction,
# sorting, filtering, and serialization.

my (undef, $TODO_FILE) = tempfile(SUFFIX => '.todo', UNLINK => 0);

my @todos;
my $next_id = 1;

say "=" x 50;
say "       PERL TODO MANAGER";
say "=" x 50;

populate_sample_data();
run_demo();

unlink $TODO_FILE;

sub run_demo {
    say "\n--- Current TODO List ---";
    list_todos();

    say "\n--- Adding New Tasks ---";
    add_todo("Write unit tests", "high", "2026-03-25");
    add_todo("Update documentation", "low", "2026-04-01");

    say "\n--- Updated List ---";
    list_todos();

    say "\n--- Complete Task #2 ---";
    complete_todo(2);

    say "\n--- Filter: Pending Only ---";
    list_todos("pending");

    say "\n--- Filter: High Priority ---";
    list_by_priority("high");

    say "\n--- Search: 'test' ---";
    search_todos("test");

    say "\n--- Statistics ---";
    show_stats();

    say "\n--- Save to File ---";
    save_todos();
    say "Saved to: $TODO_FILE";

    say "\n--- Load from File ---";
    @todos = ();
    load_todos();
    say "Loaded " . scalar(@todos) . " tasks.";
    list_todos();

    say "\n--- Delete Task #4 ---";
    delete_todo(4);

    say "\n--- Final List ---";
    list_todos();

    say "\n--- Sort by Due Date ---";
    list_sorted_by_date();

    say "\n--- Sort by Priority ---";
    list_sorted_by_priority();
}

sub populate_sample_data {
    push @todos, {
        id       => $next_id++,
        task     => "Learn Perl regular expressions",
        priority => "high",
        status   => "pending",
        due      => "2026-03-22",
        created  => "2026-03-18",
    };
    push @todos, {
        id       => $next_id++,
        task     => "Set up development environment",
        priority => "medium",
        status   => "pending",
        due      => "2026-03-21",
        created  => "2026-03-17",
    };
    push @todos, {
        id       => $next_id++,
        task     => "Read Perl best practices guide",
        priority => "medium",
        status   => "done",
        due      => "2026-03-20",
        created  => "2026-03-15",
    };
    push @todos, {
        id       => $next_id++,
        task     => "Practice file I/O exercises",
        priority => "low",
        status   => "pending",
        due      => "2026-03-28",
        created  => "2026-03-19",
    };
    push @todos, {
        id       => $next_id++,
        task     => "Build a Perl web scraper",
        priority => "high",
        status   => "pending",
        due      => "2026-04-05",
        created  => "2026-03-20",
    };
}

sub add_todo {
    my ($task, $priority, $due) = @_;
    $priority //= "medium";
    $due      //= "none";

    push @todos, {
        id       => $next_id++,
        task     => $task,
        priority => $priority,
        status   => "pending",
        due      => $due,
        created  => "2026-03-20",
    };
    say "  Added: '$task' (priority: $priority, due: $due)";
}

sub complete_todo {
    my ($id) = @_;
    for my $todo (@todos) {
        if ($todo->{id} == $id) {
            $todo->{status} = "done";
            say "  Completed: '$todo->{task}'";
            return;
        }
    }
    say "  Task #$id not found.";
}

sub delete_todo {
    my ($id) = @_;
    my @before = @todos;
    @todos = grep { $_->{id} != $id } @todos;
    if (scalar @todos < scalar @before) {
        say "  Deleted task #$id";
    } else {
        say "  Task #$id not found.";
    }
}

sub list_todos {
    my ($filter) = @_;
    my @filtered = @todos;
    if ($filter) {
        @filtered = grep { $_->{status} eq $filter } @todos;
    }

    if (!@filtered) {
        say "  No tasks found.";
        return;
    }

    printf "  %-4s %-35s %-8s %-8s %-12s\n",
        "ID", "Task", "Priority", "Status", "Due";
    printf "  %-4s %-35s %-8s %-8s %-12s\n",
        "-" x 3, "-" x 33, "-" x 8, "-" x 7, "-" x 10;

    for my $t (@filtered) {
        my $marker = $t->{status} eq "done" ? "[x]" : "[ ]";
        printf "  %-4s %-35s %-8s %-8s %-12s\n",
            "$marker",
            substr($t->{task}, 0, 33),
            $t->{priority},
            $t->{status},
            $t->{due};
    }
}

sub list_by_priority {
    my ($priority) = @_;
    my @filtered = grep { $_->{priority} eq $priority } @todos;
    if (!@filtered) {
        say "  No '$priority' priority tasks.";
        return;
    }
    for my $t (@filtered) {
        printf "  #%d %s [%s] (due: %s)\n",
            $t->{id}, $t->{task}, $t->{status}, $t->{due};
    }
}

sub search_todos {
    my ($query) = @_;
    my @found = grep { $_->{task} =~ /$query/i } @todos;
    if (!@found) {
        say "  No tasks matching '$query'.";
        return;
    }
    say "  Found " . scalar(@found) . " task(s):";
    for my $t (@found) {
        printf "    #%d %s [%s]\n", $t->{id}, $t->{task}, $t->{status};
    }
}

sub show_stats {
    my $total   = scalar @todos;
    my $pending = scalar grep { $_->{status} eq "pending" } @todos;
    my $done    = scalar grep { $_->{status} eq "done" } @todos;

    my %by_priority;
    $by_priority{$_->{priority}}++ for @todos;

    printf "  Total tasks   : %d\n", $total;
    printf "  Pending       : %d\n", $pending;
    printf "  Completed     : %d\n", $done;
    printf "  Completion %%  : %.0f%%\n", $total ? ($done / $total * 100) : 0;
    say "  By priority:";
    for my $p (qw(high medium low)) {
        printf "    %-8s : %d\n", $p, $by_priority{$p} // 0;
    }
}

sub save_todos {
    open(my $fh, '>', $TODO_FILE) or die "Cannot write $TODO_FILE: $!";
    for my $t (@todos) {
        my $line = join("\t",
            $t->{id}, $t->{task}, $t->{priority},
            $t->{status}, $t->{due}, $t->{created}
        );
        print $fh "$line\n";
    }
    close($fh);
}

sub load_todos {
    open(my $fh, '<', $TODO_FILE) or die "Cannot read $TODO_FILE: $!";
    while (my $line = <$fh>) {
        chomp $line;
        my ($id, $task, $priority, $status, $due, $created) = split /\t/, $line;
        push @todos, {
            id       => $id,
            task     => $task,
            priority => $priority,
            status   => $status,
            due      => $due,
            created  => $created,
        };
        $next_id = $id + 1 if $id >= $next_id;
    }
    close($fh);
}

sub list_sorted_by_date {
    my @sorted = sort { $a->{due} cmp $b->{due} } @todos;
    say "  Tasks sorted by due date:";
    for my $t (@sorted) {
        printf "    [%s] %-35s due: %s\n",
            $t->{status} eq "done" ? "x" : " ",
            $t->{task},
            $t->{due};
    }
}

sub list_sorted_by_priority {
    my %order = (high => 0, medium => 1, low => 2);
    my @sorted = sort { $order{$a->{priority}} <=> $order{$b->{priority}} } @todos;
    say "  Tasks sorted by priority:";
    for my $t (@sorted) {
        printf "    [%-6s] %-35s (%s)\n",
            $t->{priority}, $t->{task}, $t->{status};
    }
}
