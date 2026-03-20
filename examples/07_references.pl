#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# --- References and Nested Data Structures ---

say "=== SCALAR REFERENCES ===";

my $name = "Alice";
my $ref  = \$name;

say "Value     : $name";
say "Reference : $ref";
say "Deref     : $$ref";

$$ref = "Bob";
say "After modifying via ref, \$name = $name";

say "\n=== ARRAY REFERENCES ===";

my @colors = ("red", "green", "blue");
my $aref   = \@colors;

say "Array ref : $aref";
say "Element 0 : $aref->[0]";
say "Element 2 : $$aref[2]";
say "All       : @{$aref}";

my $anon_aref = [10, 20, 30, 40];
say "Anonymous : @{$anon_aref}";

say "\n=== HASH REFERENCES ===";

my %person = (name => "Carol", age => 28);
my $href   = \%person;

say "Hash ref  : $href";
say "Name      : $href->{name}";
say "Age       : $$href{age}";

my $anon_href = { x => 100, y => 200 };
say "Anonymous : x=$anon_href->{x}, y=$anon_href->{y}";

say "\n=== ref() — CHECKING TYPES ===";

my @refs = (\42, \@colors, \%person, sub { 1 }, $aref);
for my $r (@refs) {
    printf "  %-12s => %s\n", ref($r) || "not a ref", $r;
}

say "\n=== ARRAY OF HASHES (Records) ===";

my @students = (
    { name => "Alice", grade => "A", score => 95 },
    { name => "Bob",   grade => "B", score => 82 },
    { name => "Carol", grade => "A", score => 91 },
    { name => "Dave",  grade => "C", score => 74 },
    { name => "Eve",   grade => "B", score => 88 },
);

say "Student Records:";
printf "  %-8s %-6s %s\n", "Name", "Grade", "Score";
printf "  %-8s %-6s %s\n", "----", "-----", "-----";
for my $s (@students) {
    printf "  %-8s %-6s %d\n", $s->{name}, $s->{grade}, $s->{score};
}

my @honor_roll = grep { $_->{score} >= 90 } @students;
say "\nHonor Roll (score >= 90):";
say "  " . join(", ", map { $_->{name} } @honor_roll);

my @sorted = sort { $b->{score} <=> $a->{score} } @students;
say "\nRanked by score:";
for my $i (0 .. $#sorted) {
    printf "  %d. %s (%d)\n", $i + 1, $sorted[$i]{name}, $sorted[$i]{score};
}

say "\n=== HASH OF ARRAYS ===";

my %courses = (
    math    => [qw(Alice Bob Dave)],
    science => [qw(Carol Dave Eve)],
    english => [qw(Alice Carol Eve)],
    history => [qw(Bob Eve)],
);

say "Course Enrollments:";
for my $course (sort keys %courses) {
    my $students = join(", ", @{$courses{$course}});
    printf "  %-10s: %s\n", $course, $students;
}

say "\n=== HASH OF HASHES (Nested Config) ===";

my %config = (
    database => {
        host     => "db.example.com",
        port     => 5432,
        name     => "production",
        user     => "admin",
    },
    cache => {
        host     => "redis.local",
        port     => 6379,
        ttl      => 3600,
    },
    app => {
        debug    => 0,
        log_level => "info",
        workers  => 4,
    },
);

say "Configuration:";
for my $section (sort keys %config) {
    say "  [$section]";
    my $h = $config{$section};
    for my $key (sort keys %$h) {
        printf "    %-12s = %s\n", $key, $h->{$key};
    }
}

say "\n=== DEEPLY NESTED STRUCTURE ===";

my $company = {
    name => "Acme Corp",
    departments => {
        engineering => {
            head  => "Alice",
            teams => [
                { name => "Backend",  members => [qw(Bob Carol)] },
                { name => "Frontend", members => [qw(Dave Eve)] },
            ],
        },
        marketing => {
            head  => "Frank",
            teams => [
                { name => "Content", members => [qw(Grace Henry)] },
            ],
        },
    },
};

say "Company: $company->{name}";
for my $dept (sort keys %{$company->{departments}}) {
    my $d = $company->{departments}{$dept};
    say "  Department: $dept (Head: $d->{head})";
    for my $team (@{$d->{teams}}) {
        say "    Team: $team->{name}";
        say "      Members: " . join(", ", @{$team->{members}});
    }
}

say "\nDone!";
