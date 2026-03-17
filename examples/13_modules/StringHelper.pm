package StringHelper;
use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(trim title_case truncate_str is_palindrome word_count);

sub trim {
    my ($str) = @_;
    $str =~ s/^\s+|\s+$//g;
    return $str;
}

sub title_case {
    my ($str) = @_;
    $str = lc($str);
    $str =~ s/\b(\w)/uc($1)/ge;
    return $str;
}

sub truncate_str {
    my ($str, $max_len, $suffix) = @_;
    $max_len //= 50;
    $suffix  //= "...";
    if (length($str) > $max_len) {
        return substr($str, 0, $max_len - length($suffix)) . $suffix;
    }
    return $str;
}

sub is_palindrome {
    my ($str) = @_;
    $str = lc($str);
    $str =~ s/[^a-z0-9]//g;
    return $str eq reverse($str);
}

sub word_count {
    my ($str) = @_;
    my @words = split /\s+/, trim($str);
    return scalar @words;
}

1;
