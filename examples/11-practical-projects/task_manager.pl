#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';
use POSIX qw(strftime);
use File::Temp qw(tempfile);

# ============================================================
# Practical Project: Command-Line Task Manager
# ============================================================
# A to-do list application demonstrating file I/O,
# data structures, user interaction patterns, and
# text-based UI formatting.
# ============================================================

my ($tmpfh, $TASK_FILE) = tempfile(SUFFIX => '.tasks', UNLINK => 1);
close($tmpfh);

my @tasks;

seed_sample_data();

say "=" x 50;
say "       PERL TASK MANAGER";
say "=" x 50;
say "";

demo_operations();

say "\n" . "=" x 50;
say "Task Manager demo complete.";
say "=" x 50;

# --- Core Operations ---

sub add_task {
    my (%args) = @_;
    my $task = {
        id          => next_id(),
        title       => $args{title}       // "Untitled",
        description => $args{description} // "",
        priority    => $args{priority}    // "medium",
        status      => $args{status}      // "pending",
        created     => strftime("%Y-%m-%d %H:%M", localtime),
        due_date    => $args{due_date}    // "",
        tags        => $args{tags}        // [],
    };
    push @tasks, $task;
    save_tasks();
    return $task;
}

sub complete_task {
    my ($id) = @_;
    for my $task (@tasks) {
        if ($task->{id} == $id) {
            $task->{status} = "completed";
            $task->{completed_at} = strftime("%Y-%m-%d %H:%M", localtime);
            save_tasks();
            return 1;
        }
    }
    return 0;
}

sub delete_task {
    my ($id) = @_;
    my $before = scalar @tasks;
    @tasks = grep { $_->{id} != $id } @tasks;
    save_tasks() if scalar @tasks != $before;
    return scalar @tasks != $before;
}

sub update_task {
    my ($id, %updates) = @_;
    for my $task (@tasks) {
        if ($task->{id} == $id) {
            for my $key (keys %updates) {
                $task->{$key} = $updates{$key};
            }
            save_tasks();
            return 1;
        }
    }
    return 0;
}

sub list_tasks {
    my (%filters) = @_;
    my @filtered = @tasks;

    if (my $status = $filters{status}) {
        @filtered = grep { $_->{status} eq $status } @filtered;
    }
    if (my $priority = $filters{priority}) {
        @filtered = grep { $_->{priority} eq $priority } @filtered;
    }
    if (my $search = $filters{search}) {
        @filtered = grep {
            $_->{title} =~ /$search/i ||
            $_->{description} =~ /$search/i
        } @filtered;
    }
    if (my $tag = $filters{tag}) {
        @filtered = grep {
            grep { $_ eq $tag } @{$_->{tags}}
        } @filtered;
    }

    my $sort_by = $filters{sort_by} // "id";
    if ($sort_by eq "priority") {
        my %prio_order = (high => 0, medium => 1, low => 2);
        @filtered = sort {
            ($prio_order{$a->{priority}} // 99) <=> ($prio_order{$b->{priority}} // 99)
        } @filtered;
    } elsif ($sort_by eq "due_date") {
        @filtered = sort { ($a->{due_date} // "9") cmp ($b->{due_date} // "9") } @filtered;
    } else {
        @filtered = sort { $a->{id} <=> $b->{id} } @filtered;
    }

    return @filtered;
}

sub display_tasks {
    my (@task_list) = @_;

    if (!@task_list) {
        say "  No tasks found.";
        return;
    }

    printf "  %-4s %-8s %-10s %-30s %-12s %s\n",
        "ID", "Priority", "Status", "Title", "Due", "Tags";
    say "  " . "-" x 80;

    for my $task (@task_list) {
        my $priority_icon = priority_icon($task->{priority});
        my $status_icon   = status_icon($task->{status});
        my $tags = join(", ", @{$task->{tags} // []});
        printf "  %-4d %s %-6s %s %-8s %-30s %-12s %s\n",
            $task->{id},
            $priority_icon, $task->{priority},
            $status_icon, $task->{status},
            substr($task->{title}, 0, 30),
            $task->{due_date} // "-",
            $tags;
    }
    say "  " . "-" x 80;
    printf "  Total: %d task(s)\n", scalar @task_list;
}

sub show_task_detail {
    my ($id) = @_;
    for my $task (@tasks) {
        if ($task->{id} == $id) {
            say "\n  Task #$task->{id} Details:";
            say "  " . "-" x 40;
            printf "  Title:       %s\n", $task->{title};
            printf "  Description: %s\n", $task->{description} || "(none)";
            printf "  Priority:    %s %s\n", priority_icon($task->{priority}), $task->{priority};
            printf "  Status:      %s %s\n", status_icon($task->{status}), $task->{status};
            printf "  Created:     %s\n", $task->{created};
            printf "  Due Date:    %s\n", $task->{due_date} || "(none)";
            printf "  Tags:        %s\n", join(", ", @{$task->{tags}}) || "(none)";
            if ($task->{completed_at}) {
                printf "  Completed:   %s\n", $task->{completed_at};
            }
            return 1;
        }
    }
    say "  Task #$id not found.";
    return 0;
}

sub task_summary {
    my %summary;
    for my $task (@tasks) {
        $summary{total}++;
        $summary{$task->{status}}++;
        $summary{"priority_$task->{priority}"}++;
    }

    say "\n  Task Summary:";
    say "  " . "-" x 30;
    printf "  Total tasks:     %d\n", $summary{total} // 0;
    printf "  Pending:         %d\n", $summary{pending} // 0;
    printf "  In Progress:     %d\n", $summary{in_progress} // 0;
    printf "  Completed:       %d\n", $summary{completed} // 0;
    say "";
    printf "  High priority:   %d\n", $summary{priority_high} // 0;
    printf "  Medium priority: %d\n", $summary{priority_medium} // 0;
    printf "  Low priority:    %d\n", $summary{priority_low} // 0;

    if (($summary{total} // 0) > 0) {
        my $completion_rate = (($summary{completed} // 0) / $summary{total}) * 100;
        printf "\n  Completion rate:  %.1f%%\n", $completion_rate;
    }
}

# --- Persistence ---

sub save_tasks {
    open(my $fh, '>', $TASK_FILE) or die "Cannot save tasks: $!\n";
    for my $task (@tasks) {
        my $tags_str = join("|", @{$task->{tags} // []});
        printf $fh "%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
            $task->{id}, $task->{title}, $task->{description} // "",
            $task->{priority}, $task->{status}, $task->{created},
            $task->{due_date} // "", $tags_str, $task->{completed_at} // "";
    }
    close($fh);
}

sub load_tasks {
    return unless -f $TASK_FILE;
    open(my $fh, '<', $TASK_FILE) or return;
    @tasks = ();
    while (my $line = <$fh>) {
        chomp $line;
        my @fields = split /\t/, $line, -1;
        next unless @fields >= 8;
        push @tasks, {
            id           => $fields[0],
            title        => $fields[1],
            description  => $fields[2],
            priority     => $fields[3],
            status       => $fields[4],
            created      => $fields[5],
            due_date     => $fields[6],
            tags         => [grep { $_ ne "" } split(/\|/, $fields[7] // "")],
            completed_at => $fields[8] // "",
        };
    }
    close($fh);
}

# --- Helpers ---

sub next_id {
    my $max = 0;
    for my $task (@tasks) {
        $max = $task->{id} if $task->{id} > $max;
    }
    return $max + 1;
}

sub priority_icon {
    my ($p) = @_;
    return "[!]" if $p eq "high";
    return "[-]" if $p eq "medium";
    return "[ ]" if $p eq "low";
    return "[?]";
}

sub status_icon {
    my ($s) = @_;
    return "[x]" if $s eq "completed";
    return "[>]" if $s eq "in_progress";
    return "[ ]" if $s eq "pending";
    return "[?]";
}

# --- Demo ---

sub seed_sample_data {
    add_task(
        title       => "Learn Perl basics",
        description => "Complete the variables and data types tutorial",
        priority    => "high",
        due_date    => "2026-03-25",
        tags        => ["learning", "perl"],
    );
    add_task(
        title       => "Write unit tests",
        description => "Add test coverage for MathUtils module",
        priority    => "medium",
        due_date    => "2026-03-28",
        tags        => ["testing", "perl"],
    );
    add_task(
        title       => "Read Modern Perl book",
        description => "Available free online at modernperlbooks.com",
        priority    => "low",
        due_date    => "2026-04-15",
        tags        => ["learning", "reading"],
    );
    add_task(
        title       => "Build log analyzer",
        description => "Create a practical Perl project for log analysis",
        priority    => "high",
        status      => "in_progress",
        due_date    => "2026-03-22",
        tags        => ["project", "perl"],
    );
    add_task(
        title       => "Review regex patterns",
        description => "Practice advanced regular expressions",
        priority    => "medium",
        tags        => ["learning", "regex"],
    );
}

sub demo_operations {
    say "--- ALL TASKS ---";
    display_tasks(list_tasks());

    say "\n--- COMPLETING TASK #1 ---";
    complete_task(1);
    say "Task #1 marked as completed.";

    say "\n--- ADDING A NEW TASK ---";
    my $new = add_task(
        title       => "Deploy to production",
        description => "Push the latest release to prod servers",
        priority    => "high",
        due_date    => "2026-03-21",
        tags        => ["deployment", "urgent"],
    );
    say "Added: Task #$new->{id} - $new->{title}";

    say "\n--- UPDATING TASK #2 ---";
    update_task(2, status => "in_progress", priority => "high");
    say "Task #2 updated to in_progress, high priority.";

    say "\n--- FILTER: HIGH PRIORITY ---";
    display_tasks(list_tasks(priority => "high"));

    say "\n--- FILTER: PENDING TASKS ---";
    display_tasks(list_tasks(status => "pending"));

    say "\n--- FILTER: TASKS TAGGED 'learning' ---";
    display_tasks(list_tasks(tag => "learning"));

    say "\n--- SEARCH: 'perl' ---";
    display_tasks(list_tasks(search => "perl"));

    say "\n--- TASK DETAIL ---";
    show_task_detail(4);

    say "\n--- DELETING TASK #3 ---";
    delete_task(3);
    say "Task #3 deleted.";

    say "\n--- FINAL TASK LIST (sorted by priority) ---";
    display_tasks(list_tasks(sort_by => "priority"));

    task_summary();
}
