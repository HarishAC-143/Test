#!/usr/bin/perl
# Demonstrates working with JSON data and HTTP APIs using core modules.

use strict;
use warnings;
use JSON::PP;
use HTTP::Tiny;

print "=== JSON ENCODING AND DECODING ===\n\n";

my $data = {
    name    => "Perl Tutorial",
    version => "1.0",
    topics  => ["scalars", "arrays", "hashes", "regex", "OOP"],
    metadata => {
        author  => "Tutorial Author",
        license => "MIT",
        year    => 2026,
    },
};

my $json_str = JSON::PP->new->pretty->canonical->encode($data);
print "Encoded JSON:\n$json_str\n";

my $decoded = decode_json($json_str);
printf "Decoded — Name: %s, Topics: %d, Author: %s\n\n",
       $decoded->{name},
       scalar @{$decoded->{topics}},
       $decoded->{metadata}{author};

print "=== WORKING WITH JSON DATA ===\n\n";

my $json_records = <<'JSON';
[
    {"name": "Alice", "department": "Engineering", "skills": ["Perl", "Python", "SQL"]},
    {"name": "Bob", "department": "Marketing", "skills": ["Analytics", "SEO"]},
    {"name": "Carol", "department": "Engineering", "skills": ["Perl", "Go", "Docker"]},
    {"name": "Dave", "department": "Sales", "skills": ["CRM", "Negotiation"]}
]
JSON

my $team = decode_json($json_records);

my %dept_count;
my %all_skills;

for my $person (@$team) {
    $dept_count{$person->{department}}++;
    $all_skills{$_}++ for @{$person->{skills}};
}

print "Department headcount:\n";
for my $dept (sort keys %dept_count) {
    printf "  %-15s %d\n", $dept, $dept_count{$dept};
}

print "\nSkill frequency:\n";
for my $skill (sort { $all_skills{$b} <=> $all_skills{$a} } keys %all_skills) {
    printf "  %-15s %d\n", $skill, $all_skills{$skill};
}

my @engineers = grep { $_->{department} eq "Engineering" } @$team;
print "\nEngineers:\n";
for my $eng (@engineers) {
    printf "  %s — skills: %s\n", $eng->{name}, join(", ", @{$eng->{skills}});
}

print "\n=== HTTP API REQUEST ===\n\n";

my $http = HTTP::Tiny->new(timeout => 10);
my $response = $http->get('https://jsonplaceholder.typicode.com/todos?_limit=5');

if ($response->{success}) {
    my $todos = decode_json($response->{content});

    printf "%-4s %-50s %s\n", "ID", "Title", "Done?";
    print "-" x 65, "\n";

    for my $todo (@$todos) {
        printf "%-4d %-50s %s\n",
               $todo->{id},
               substr($todo->{title}, 0, 48),
               $todo->{completed} ? "Yes" : "No";
    }
} else {
    printf "HTTP request failed: %s %s\n", $response->{status}, $response->{reason};
    print "(This is expected if running without internet access.)\n";
}

print "\n=== BUILDING A CONFIG SYSTEM WITH JSON ===\n\n";

my %defaults = (
    host     => "localhost",
    port     => 8080,
    debug    => 0,
    log_file => "/var/log/app.log",
    workers  => 4,
);

my $user_config_json = '{"port": 3000, "debug": true, "workers": 8}';
my $user_config = decode_json($user_config_json);

my %final_config = (%defaults, %$user_config);

print "Final configuration (defaults + overrides):\n";
my $config_json = JSON::PP->new->pretty->canonical->encode(\%final_config);
print $config_json;
